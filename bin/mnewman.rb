#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "nysol/mcmd"

$version="1.0"
$revision="###VERSION###"
CMD="mnewman.rb"

def help
STDERR.puts <<EOF
----------------------------
#{CMD} version #{$version}
----------------------------
概要) newman クラスタリング
特徴) 1) modularityの最適化を用いたクラスタリングが実施できる。
      2) 辺の媒介中心性を利用したグラフ分割によるクラスタリングが実施できる。
書式) #{CMD} ei= ef= ni= [nf=] [ew=] [al=]  o= [-directed]

  ei=   : 枝データファイル
  ef=   : 枝データ上の2つの節点項目名
  ni=   : 節点データファイル
  nf=   : 節点データ上の節点項目名
  ew=   : 枝ファイル上の重み項目名【省略時は全ての枝の重みを1と見なす】
  al=   : クラスタリングアルゴリズム。省略時はmoが選択される。
          mo:(modularity optimization) modularityを最適化するための貪欲法によるクラスタリング
              無向グラフでのみ指定可能。igraphのcluster_fast_greedyを利用
          eb:(edge betweenness) 辺の媒介中心性を計算し最もそれが高い辺を取り除くことでグラフを分割する。
              分割数はmodurarityが最大となるように決定される。igraphのcluster_edge_betweennessを利用
  -directed : 有向グラフ
  o=     : クラスタ

  その他
  T= : ワークディレクトリ(default:/tmp)
  -verbose : show the END messages of MCMD and R used in this command
  --help : ヘルプの表示

必要なソフトウェア)
	1) R
	2) igraph package for R

入力データ)
節点ペアのCSVファイル(ファイル名はei=にて指定)
例)
$ cat data/dat1.edge
n1,n2
a,b
a,c
a,d
a,e
a,f
a,g
b,c
b,d
b,e
b,f
c,h
d,g
e,f

$ cat data/dat.node
node
a
b
c
d
e
f
g

${CMD} ei=data/dat1.edge ef=n1,n2 al=mo o=rsl01
#END# mnewman.rb ei=./data/dat1.edge ef=n1,n2 al=mo o=rsl01; 2016/01/24 01:54:25

$ cat rsl01
node,cls
a,2
b,1
c,3
d,2
e,1
f,1
g,2
h,3

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

# confirm if R library is installed
exit(1) unless(MCMD::chkRexe("igraph"))


####
# converting original graph file with text to one with integer
# output #{numFile} and #{mapFile}, then return the number of nodes of the graph
#
# ei    ni   xxnum   xxmap
# v1,v2 v            node%1,flag%0,num
# E,J   A     0 3    A,0,0
# E,A   B     0 4    B,0,1
# J,D   C     0 6    D,0,2
# J,A   D =>  1 5    E,0,3
# J,H   E     2 4    F,0,4
# D,H   F     2 5    H,0,5
# D,F   G     2 6    J,0,6
# H,F   H     3 6    C,1,7
# A,F   I     4 5    G,1,8
# B,H   J     5 6    I,1,9
#
# return value is 10 (nodes)
# "flag" on xxmap: 0:nodes in "ei", 1:nodes only in "ni".
def g2pair(ni,nf,ei,ef1,ef2,ew,numFile,mapFile,weightFile)
  #MCMD::msgLog("converting graph files into a pair of numbered nodes ...")
  wf=MCMD::Mtemp.new
  wf1=wf.file
  wf2=wf.file
  wf3=wf.file

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
  # isolated nodes are set to the end of position in mapping file.
  # S= must start from 0 (but inside R vertex number will be added one)
  f << "mnumber s=flag,node a=num S=0 o=#{mapFile}"
  system(f)

  f=""
  f << "mcut f=#{ef1},#{ef2} i=#{ei} |"
  f << "msortf f=#{ef1} |"
  f << "mjoin  k=#{ef1} K=node m=#{mapFile} f=num:num1 |"
  f << "msortf f=#{ef2} |"
  f << "mjoin  k=#{ef2} K=node m=#{mapFile} f=num:num2 |"
  f << "mcut   f=num1,num2 |"
  f << "mfsort f=num1,num2 |"
  f << "msortf f=num1%n,num2%n -nfno | tr ',' ' ' >#{numFile}"
  system(f)

  nodeSize=MCMD::mrecount("i=#{mapFile}")

	if ew
		system "mcut f=#{ew} i=#{ei} o=#{weightFile}"
	else
		ew="weight"
		system "msetstr v=1 a=#{ew} i=#{ei} |mcut f=#{ew} o=#{weightFile}"
	end

  return nodeSize
end

def convOrg(xxmap,xxout,ofile)

  wf=MCMD::Mtemp.new
  xx1=wf.file
  xx2=wf.file

	system "mnumber S=0 a=num -q i=#{xxout} o=#{xx1}"

	f=""
	f << "mjoin k=num f=cls m=#{xx1} i=#{xxmap} |"
	f << "mcut f=node,cls o=#{ofile}"
	system(f)	

end



def genRscript(directed,eFile,wFile,ew,nodeSize,al,oFile,oInfo,scpFile)
  dir="FALSE"
  dir="TRUE" if directed

#system "cp #{eFile} xxedge"
#system "cp #{wFile} xxweight"

if al=="mo"
  raise "#ERROR# can't use -directed option with al=\"mo\" " if directed
  r_proc = <<EOF
library(igraph)
# reading edge file
g=read.graph("#{eFile}",format="edgelist",directed=#{dir},n=#{nodeSize})
# reading weight file
w=read.csv("#{wFile}")
E(g)$weight=as.list(w$"#{ew}")
# do clustering
nc=cluster_fast_greedy(g,weight=E(g)$weight,merges=T,modularity=T,membership=T)

# 置換
ms=cbind(membership(nc))
# Community sizes:
cs=sizes(nc)

# modularity:
mq=modularity(nc)

dat=data.frame( cls=ms )
colnames(dat)=c("cls")

info=data.frame(cs, mq)
colnames(info)=c("cls","size","modurarityQ")

write.csv(dat,file="#{oFile}",quote=FALSE,row.names=FALSE)
write.csv(info,file="#{oInfo}",quote=FALSE,row.names=FALSE)
EOF

else # eb (edge betweenness)
  r_proc = <<EOF
library(igraph)
# reading edge file
g=read.graph("#{eFile}",format="edgelist",directed=#{dir},n=#{nodeSize})
# reading weight file
w=read.csv("#{wFile}")
E(g)$weight=as.list(w$"#{ew}")
# do clustering
nc=cluster_edge_betweenness(g,weights=E(g)$weight,directed=#{dir},bridges=T,merges=T,modularity=T,edge.betweenness=T,membership=T)

# 置換
ms=cbind(membership(nc))
# Community sizes:
cs=sizes(nc)

# modularity:
mq=modularity(nc)

dat=data.frame( cls=ms )
colnames(dat)=c("cls")

info=data.frame(cs, mq)
colnames(info)=c("cls","size","modurarityQ")

write.csv(dat,file="#{oFile}",quote=FALSE,row.names=FALSE)
write.csv(info,file="#{oInfo}",quote=FALSE,row.names=FALSE)
EOF

end


  File.open(scpFile,"w"){|fpw|
    fpw.write(r_proc)
  }
end



#################################################################################################
#### Entry point

args=MCMD::Margs.new(ARGV,"ei=,ef=,ni=,nf=,ew=,al=,o=,-directed,T=,-verbose,--help","ei=")

ENV["KG_VerboseLevel"]="2" unless args.bool("-verbose")

# work file path
if args.str("T=")!=nil then
  ENV["KG_TmpPath"] = args.str("T=").sub(/\/$/,"")
end

# 出力ファイル
ofile =args.file("o=","w")

# 枝データの扱い
# setting variables for edge file(s) and its field name
edgeFile=nil
edgeFile = args.file("ei=","r") # edge file name
unless edgeFile
  raise "#ERROR# ei= is mandatory"
end
ef = args.field("ef=", edgeFile)
ef1,ef2=ef["names"]

# ---- 枝重み
ew = args.field("ew=", edgeFile, nil, 1,1)
ew = ew["names"][0] if ew

# 節点データの扱い
# if nf= is not specified, only edge files are used for generating a graph.
ni=nil
nodeFile=nil
nodeFile = args.file("ni=","r") # node file name
if nodeFile
  nf = args.field("nf=", nodeFile)
  unless nf
    raise "#ERROR# nf= is mandatory, when ni= is specified"
  end
    nf=nf["names"][0]
end

# アルゴリズム
al = args.str("al=","mo")    # Default=mo 
unless al=="mo" or al=="eb"
      raise "#ERROR# al= can specify mo|eb"
end


# 有向or無向グラフ
directed=args.bool("-directed")

# convert the original graph to one igraph can handle
  wf=MCMD::Mtemp.new
  xxnum =wf.file
  xxmap =wf.file
  xxout =wf.file
  xxscp =wf.file
	xxinfo=wf.file
	xxweight=wf.file

  nodeSize=g2pair(nodeFile,nf,edgeFile,ef1,ef2,ew,xxnum,xxmap,xxweight)

  # generate R script, and run
  genRscript(directed,xxnum,xxweight,ew,nodeSize,al,xxout,xxinfo,xxscp)

  if args.bool("-verbose")
    system "R --vanilla -q < #{xxscp}"
  else
    system "R --vanilla -q --slave < #{xxscp} 2>/dev/null"
  end

	# 元のデータに戻して出力
	convOrg(xxmap,xxout,ofile)

#system "cp #{xxweight} xxweight"
#system "cp #{xxmap} xxmap"
#system "cp #{xxout} xxdat"
#system "cp #{xxinfo} xxinfo"

MCMD::endLog(args.cmdline)


