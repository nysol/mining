#!/usr/bin/env ruby
# encoding: utf-8

# 1.0 initial development: 2015/10/20
# 1.1 minor modifications: 2015/12/09
$version="1.0"
$revision="###VERSION###"
CMD="mgfeatures.rb"

def help

STDERR.puts <<EOF
----------------------------
#{CMD} version #{$version}
----------------------------
summary) calculation graph features by netal
feature) output the following graph features

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

require "rubygems"
require "nysol/mcmd"
CMD_netal="netal_outcsv"

####
# converting original graph file with text to one with integer

def g2pair(ni,nf,ei,ef1,ef2,numFile,mapFile)
	wf=MCMD::Mtemp.new
	wf1=wf.file
	wf2=wf.file
	wf3=wf.file
	wf4=wf.file
	system "mcut f=#{ef1}:node i=#{ei} | msetstr v=0 a=flag o=#{wf1}"
	system "mcut f=#{ef2}:node i=#{ei} | msetstr v=0 a=flag o=#{wf2}"
	system "mcut f=#{nf}:node  i=#{ni} | msetstr v=1 a=flag o=#{wf3}" if nf

	f=""
	if nf
		f << "mcat i=#{wf1},#{wf2},#{wf3} f=node,flag |"
		f << "mbest k=node s=flag from=0 size=1 |"
	else
		f << "mcat  i=#{wf1},#{wf2}       f=node,flag |"
		f << "muniq k=node |"
	end
	f << "mnumber s=flag%r,node a=num S=1 |"
	f << "msortf f=node o=#{wf4}"
	system(f)

	f=""
	f << "mcut f=#{ef1},#{ef2} i=#{ei} |"
	f << "msortf f=#{ef1} |"
	f << "mjoin  k=#{ef1} K=node m=#{wf4} f=num:num1 |"
	f << "msortf f=#{ef2} |"
	f << "mjoin  k=#{ef2} K=node m=#{wf4} f=num:num2 |"
	f << "mcut   f=num1,num2 |"
	f << "msortf f=num1%n,num2%n -nfno | tr ',' ' ' >#{numFile}"
	system(f)

	f=""
	f << "msortf f=num i=#{wf4} o=#{mapFile}"
	system(f)	
	
end

#################################################################################################
#### Entry point
# ei : エッジファイル
# ef : エッジ項目名(２項目)
# ni : ノードファイル
# nf : ノード項目名
# o  : 結果サマリー
# no : ノードインフォ
# eo : エッジインフォ
# -directed : 有向グラフ指定


args=MCMD::Margs.new(ARGV,"ei=,ef=,ni=,nf=,o=,eo=,no=,-directed,T=,-verbose,-gz","ei=,ef=")



# パラメータ設定
eifn = args.file("ei=","r")
raise "#ERROR# ei= is mandatory" unless eifn
ef1,ef2 = args.field("ef=", eifn)["names"]
nifn = args.file("ni=","r")
nf = args.field("nf=", nifn)["names"][0] if nifn
otfn = args.file("o=","w")
nofn = args.file("no=","w")
eofn = args.file("eo=","w")
directed=args.bool("-directed")
gzFLG=args.bool("-gz")


# 環境変数設定
ENV["KG_VerboseLevel"]="2" unless args.bool("-verbose")
ENV["KG_TmpPath"] = args.str("T=").sub(/\/$/,"") if args.str("T=")!=nil 

# 一時ファイル用意
wf=MCMD::Mtemp.new
xxdata = wf.file
xxmap  = wf.file
xxon  = wf.file
xxoe  = wf.file


# netal用ファイル作成
g2pair(nifn,nf,eifn,ef1,ef2,xxdata,xxmap)
#edgeファイルが０バイトの場合netalを起動しない
if MCMD::mrecount("i=#{xxdata} -nfn") !=0 then
	f = ""
	f << "UNDIRECTED=1 " unless directed
	f << "#{CMD_netal} "
	f << "-i #{xxdata} "
	f << "-t snap -z cent uCGSBD 1 "
	f << "-o #{otfn} " if otfn
	f << "-oN #{xxon} "  if nofn
	f << "-oE #{xxoe} "  if eofn
	f << "> /dev/null"
	system(f)
	# データ変換
	if nofn then
		f =""
		f << "mjoin i=#{xxon} k=node K=num f=node:Node m=#{xxmap}|"
		if gzFLG then
			f << "mcut f=0L,1-1L -x |"
			f << "gzip -c > #{nofn}"
		else 
			f << "mcut f=0L,1-1L -x o=#{nofn}"
		end
		system(f)
	end
	if eofn then
		f =""
		f << "mjoin i=#{xxoe}  k=from K=num  f=node:nodeF m=#{xxmap} |"
		f << "mjoin k=to K=num  f=node:nodeT m=#{xxmap} |"
		if gzFLG then
			# データ変換
			f << "mcut f=1L-0L,2-2L -x |"
			f << "gzip -c > #{eofn}"
		else
			f << "mcut f=1L-0L,2-2L -x o=#{eofn}"
		end
		system(f)
	end

else #ダミー出力
	fld =[
		"node_size","edge_size","degree0_node_size","mean_degree",
		"median_degree","min_degree","max_degree","graph_density",
		"transitivity","average_shortest_path","diameter"
	]
	if otfn then
		node_N = MCMD::mrecount("i=#{xxmap}")
		outdt = [node_N,0,node_N,0,0,0,0,0,0,0,0]
		oCSV=MCMD::Mcsvout.new("f=#{fld.join(',')} o=#{otfn}")
		oCSV.write(outdt)
		oCSV.close
		
	end
	# データ変換
	if nofn then
		fld="Closeness,Degree,Graph,Betweenness,Stress"
		f =""
		f << "mcut f=node:Node i=#{xxmap} |"
		f << "msortf f=Node |"
		if gzFLG then
			f << "msetstr a=#{fld} v=0,0,0,0,0 |"
			f << "gzip -c > #{nofn}"
		else
			f << "msetstr a=#{fld} v=0,0,0,0,0 o=#{nofn}"		
		end
		system(f)
	end
	if eofn then
		fld ="nodeF,nodeT,Betweenness,Stress"
		if gzFLG then
			oCSV=MCMD::Mcsvout.new("f=#{fld} o=#{xxoe}")
			oCSV.close
			system("gzip -c #{xxoe} > #{eofn}")
		else
			oCSV=MCMD::Mcsvout.new("f=#{fld} o=#{eofn}")
			oCSV.close
		end
	end

end




# end message
MCMD::endLog(args.cmdline)

