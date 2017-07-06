#!/usr/bin/env ruby
# encoding: utf-8

# 1.0 initial development: 2016/1/27
$version="1.0"
$revision="###VERSION###"
CMD="mgnfeatures.rb"

def help

STDERR.puts <<EOF
----------------------------
#{CMD} version #{$version}
----------------------------
概要) ノードの特徴量を計算
特徴) 以下のノードの特徴量を出力
  degree      : 各ノードの次数
	cc          : クラスタ係数
  components  : 連結成分 (連結成分をクラスタとする)
  betweenness : 媒介中心性 (ある点が他の点間の最短経路に位置する程度)
  closeness   : 近接中心性 (他の点への最短経路の合計の逆数)
  page_rank   : 各ノードの重要度をpage_rankで計算

書式) #{CMD} I=|(ei= [ni=]) ef= [nf=] [ew=] [mode=] O= [-directed] [-normalize] [T=] [-verbose] [--help]
  I=     : 入力パス
         : パス中の枝ファイルは.edge拡張子が前提
         : パス中の点ファイルは.node拡張子が前提
  ei=    : 枝データファイル(I=とは一緒に指定できない)
  ef=    : 枝データ上の2つの節点項目名
  ni=    : 節点データファイル(I=とは一緒に指定できない)
  nf=    : 節点データ上の節点項目名(省略時は"node")
  ew=    : 枝ファイル上の重み項目名【省略時は全ての枝の重みを1と見なす】
  mode=  : in|out|all (-directedを指定した場合のみ有向。省略時は"all"。詳しくは詳細)を参照)
  O=     : 出力パス
  -directed  : 有向グラフ
  -normalize : 基準化

  その他
  T= : ワークディレクトリ(default:/tmp)
  -verbose : show the END messages of MCMD and R used in this command
  --help : ヘルプの表示

必要なソフトウェア)
  1) R
  2) igraph package for R

詳細)
1.オプション一覧
             | mode        | 重み |    基準化
---------------------------------------------------------------------
 degree      |in,out,all   | 無し | n-1で割る
 cc          | 無し        | 有り | 無し
 components  | 無し        | 無し | 無し
 betweenness | 無し        | 有り | 2B/(n^2-3n+2) [B:raw betweenness]
 closeness   |in,out,all   | 有り | n-1で割る
 page_rank   | 無し        | 有り | 無し
-------------------------------------------------------------------- 
modeは-directedを指定された場合に有効になる。
in:入枝が対象, out:出枝が対象, all: 両方対象を意味する

2. ccは-directedが指定されていても無視される。
3. componentsは-directedが指定された場合には強連結を求める。
4. pageRankは"prpack"を利用。

入力データ)
２つの節点からなる枝データ

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

$ mgnfeatures.rb ei=data/dat1.edge ef=n1,n2 O=rsl01
$ cat rsl01/dat1.csv
node,degree,components,betweenness,closeness,page_rank
a,6,1,8.5,0.125,0.216364844231035
b,5,1,4,0.111111111111111,0.181335882714211
c,3,1,6,0.0909090909090909,0.126673483636635
d,3,1,0.5,0.0833333333333333,0.11508233404895
e,3,1,0,0.0833333333333333,0.111947143712761
f,3,1,0,0.0833333333333333,0.111947143712761
g,2,1,0,0.0769230769230769,0.0820083475799325
h,1,1,0,0.0588235294117647,0.0546408203637134

# Copyright(c) NYSOL 2014- All Rights Reserved.
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

# Rライブラリ実行可能確認
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

def genRscript(directed,norm,mode,eFile,wFile,ew,nodeSize,oFile,scpFile)
	dir="FALSE"
	dir="TRUE" if directed
	normalize="FALSE"
	normalize="TRUE" if norm

  r_proc = <<EOF
library(igraph)
#### reading edge file
g=read.graph("#{eFile}",format="edgelist",directed="#{dir}",n="#{nodeSize}")
# reading weight file
w=read.csv("#{wFile}")
E(g)$weight=as.list(w$"#{ew}")

####
deg=degree(g,mode="#{mode}",normalized="#{normalize}")
### ew=がnullの場合はweight=1として扱っているので以下で問題ない
cc=transitivity(g,type="weight")
cls=components(g,mode="strong")

# -normalizeと-directedは一緒に指定できないため以下の処理を行う
if ("#{dir}"=="TRUE") {
	norm2 = "FALSE"
	betweenness=betweenness(g,directed="#{dir}",weight=E(g)$weight,normalized=norm2)
} else {
	norm2 = "#{normalize}"
	betweenness=betweenness(g,directed="#{dir}",weight=E(g)$weight,normalized=norm2)
}

closeness=closeness(g,weight=E(g)$weight,mode="#{mode}",normalized="#{normalize}")
pgrank=page.rank(g,weight=E(g)$weight,directed="#{dir}")$vector

dat=data.frame(
  degree=deg,
	cc=cc,
  components=cls$membership,
	betweenness=betweenness,
	closeness=closeness,
	page_rank=pgrank
)

write.csv(dat,file="#{oFile}",quote=FALSE,row.names=FALSE)

EOF

  File.open(scpFile,"w"){|fpw|
    fpw.write(r_proc)
  }
end

#################################################################################################
#### Entry point

args=MCMD::Margs.new(ARGV,"I=,ei=,ef=,ni=,nf=,ew=,O=,mode=,-directed,-normalize,-verbose,mp=","ef=,O=")


# suppress the end message of MCMD
ENV["KG_VerboseLevel"]="2" unless args.bool("-verbose")

# work file path
if args.str("T=")!=nil then
  ENV["KG_TmpPath"] = args.str("T=").sub(/\/$/,"")
end

# setting variables for edge file(s) and its field name
iPath = args.file("I=","r")
oPath = args.file("O=","w")

# 枝データの扱い
edgeFiles=nil
ef1  =nil
ef2  =nil
if iPath then
  edgeFiles = Dir["#{iPath}/*.edge"]
  if edgeFiles.size==0 then
    raise "#ERROR# no edge file is found matching with #{iPath}/*.edge"
  end
  ef = args.field("ef=", edgeFiles[0])
  ef1,ef2=ef["names"]
else
  edgeFiles = args.file("ei=","r").split # edge file name
  unless edgeFiles
    raise "#ERROR# ei= or I= is mandatory"
  end
  ef = args.field("ef=", edgeFiles[0])
  ef1,ef2=ef["names"]
end

# ---- 枝重み
ew = args.field("ew=", edgeFiles[0], nil, 1,1)
ew = ew["names"][0] if ew

# 節点データの扱い
# if nf= is not specified, only edge files are used for generating a graph.
ni=nil
nf=nil
if iPath then
  nodeFile0=edgeFiles[0].sub(/\.edge/,".node")
  if File.exists?(nodeFile0)
    nf = args.field("nf=", nodeFile0)
    if nf
      nf=nf["names"][0]
    end
  else
    nf = args.str("nf=")
    if nf then
      raise "#ERROR# nf= is specified, but no node file is found matching with #{iPath}/*.node"
    end
  end
else
  ni = args.file("ni=","r") # node file name
  if ni
    nf = args.field("nf=", ni)
    unless nf
      raise "#ERROR# nf= is mandatory, when ni= is specified"
    end
    nf=nf["names"][0]
  end
end

mode=args.str("mode=","all")
unless mode=="all" or mode=="in" or mode=="out" 
      raise "#ERROR# mode= can specify all|in|out"
end

directed=args.bool("-directed")
norm=args.bool("-normalize")
MP=args.int("mp=",4)

MCMD::mkDir(oPath)

edgeFiles.meach(MP){|edgeFile|
  #MCMD::msgLog("START fearture extraction: #{edgeFile}")

  baseName=edgeFile.sub(/\.edge$/,"")
  name=baseName.sub(/^.*\//,"")

	if ni
		nodeFile=ni	
	else
  	nodeFile=edgeFile.sub(/\.edge$/,".node")
	end

  # convert the original graph to one igraph can handle
  wf=MCMD::Mtemp.new
  xxnum=wf.file
  xxmap=wf.file
  xxout=wf.file
  xxscp=wf.file
  xxweight=wf.file

  nodeSize=g2pair(nodeFile,nf,edgeFile,ef1,ef2,ew,xxnum,xxmap,xxweight)
=begin
system "cat #{xxnum}"
system "cat #{xxmap}"
puts "nodeSize=#{nodeSize}"
=end
	
  # generate R script, and run
  genRscript(directed, norm, mode, xxnum, xxweight, ew, nodeSize, xxout, xxscp)
  if  args.bool("-verbose")
    system "R --vanilla -q < #{xxscp}"
  else
		
  #  system "R --vanilla -q < #{xxscp} &>/dev/null"
    system "R --vanilla -q --slave < #{xxscp} 2>/dev/null "
    #system "Rscript #{xxscp}"

  end

  # store the result
	f=""
	f << "mnumber -q S=0 a=num i=#{xxout} |"
	f << "mjoin k=num f=node m=#{xxmap} |"
	if nf
	f << "mcut f=node:#{nf},degree,cc,components,betweenness,closeness,page_rank o=#{oPath}/#{name}.csv" 
	else
	f << "mcut f=node,degree,cc,components,betweenness,closeness,page_rank o=#{oPath}/#{name}.csv" 
	end
	system(f)

}

# end message
MCMD::endLog(args.cmdline)
