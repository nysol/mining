#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "nysol/mcmd"
require "json"

# 1.0: first release: 2015/5/5
$version="1.0"
$revision="###VERSION###"

def help

STDERR.puts <<EOF
----------------------------
msm.rb version #{$version}
----------------------------
概要) shift mean clustering
特徴) 1) RパッケージLPCMを利用している。
用法) msm.rb f= i= h= [O=] [--help]

  f=   : i=ファイル上の変数項目名【必須】
  i=   : 入力ファイル名【必須】
	h=   : band width
  O=   : 出力パス【必須】
	-debug : Rの実行結果を表示

  その他
	--help   : ヘルプの表示

必要なソフトウェア)
  1) R
  2) RのLPCMパッケージ

# Copyright(c) NYSOL 2012- All Rights Reserved.
EOF
exit
end

def ver()
	$revision ="0" if $revision =~ /VERSION/
	STDERR.puts "version #{$version} revision #{$revision}"
	exit
end

help() if ARGV[0]=="--help" or ARGV.size <= 0
ver()  if ARGV[0]=="--version"

args=MCMD::Margs.new(ARGV,"f=,h=,i=,o=,O=,-debug,-mcmdenv,T=","f=,h=,i=,o=")

# mcmdのメッセージは警告とエラーのみ
ENV["KG_VerboseLevel"]="2" unless args.bool("-mcmdenv")

# Rライブラリ実行可能確認
exit(1) unless(MCMD::chkRexe("LPCM"))

#ワークファイルパス
if args.str("T=")!=nil then
	ENV["KG_TmpPath"] = args.str("T=").sub(/\/$/,"")
end

iFile = args.file("i=","r")
oFile = args.file("o=","w")
flds  = args.field("f=", iFile)
names = flds["names"].join(",")
newnames = flds["newNames"]
if newnames.index(nil)
	raise "#ERROR# f= parameter takes new field names for output."
end

bw    = args.float("h=")
oPath = args.file("O=","w")
$debug = args.bool("-debug")

MCMD::mkDir(oPath) if oPath

def runR(names,bw,csv,wp)
	wf=MCMD::Mtemp.new
	scp=wf.file #"xxscp"

	r_scp = <<EOF
library('LPCM')
d=read.csv("#{csv}")
cm=colMeans(d)
#print(cm)
sftM=function(x){return(x-cm)}
sftP=function(x){return(x+cm)}
dd=t(apply(d,1,sftM))
#print(dd)
model=ms(dd,h=#{bw},plotms=F)

center=t(apply(model$cluster.center,1,sftP))
#print(model$cluster)
#print(center)

#ms.self.coverage(d, taumin=0.02, taumax=0.5, gridsize=25,
#thr=0.0001, scaled=TRUE, cluster=FALSE, plot.type="o",
#or.labels=NULL, print=FALSE)

#print(model)
#write.csv(model$cluster.center,"#{wp}/xxcluster")
write.csv(center,"#{wp}/xxcluster")
write.csv(model$cluster.label ,"#{wp}/xxlabel")

#png("#{wp}/gpr.png")
#  plot(model,as="improv")
#dev.off()
EOF

	File.open(scp,"w"){|fpw| fpw.write r_scp}
	if $debug
		system "R --vanilla -q < #{scp}"
	else
		system "R --vanilla -q < #{scp} &>/dev/null"
	end
end

# cluster.csv
# "","V1","V2"
# "1",0.107262943725142,0.0329636308034888
# "2",-0.655560794404871,-0.448416202492924
# "3",-0.218883486000835,0.44341544263141

# label.csv
# "","x"
# "1",1
# "2",1
# "3",1

wf=MCMD::Mtemp.new
xxbase  =wf.file
xxwp    =wf.file
xxcmf   =wf.file
xxlabel =wf.file
MCMD::mkDir(xxwp)

system "mcut f=#{names} i=#{iFile} o=#{xxbase}"

runR(names,bw,xxbase,xxwp)

#
nn=[]
(1..newnames.size).each{|i|
	nn << "#{i}:#{newnames[i-1]}"
}

# cluster master file
f=""
f << "tail +2 <#{xxwp}/xxcluster |"
f << "mcut f=0:cluster,#{nn.join(",")} -nfni o=#{xxcmf}"
system(f)

# label file
f=""
f << "tail +2 <#{xxwp}/xxlabel |"
f << "mcut f=1:cluster -nfni o=#{xxlabel}"
system(f)

# join cmf and label file to ifile
f=""
f << "mpaste m=#{xxlabel} i=#{iFile} |"
f << "mjoin  k=cluster m=#{xxcmf} o=#{oFile}"
system(f)

if oPath then
	system "cp #{xxcmf}   #{oPath}/cluster.csv"
	system "cp #{xxlabel} #{oPath}/label.csv"
end

# 終了メッセージ
MCMD::endLog(args.cmdline)

