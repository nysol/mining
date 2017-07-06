#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "nysol/mcmd"

# 1.1: change from ufactor= to balance=, bug fix for isolated nodes
$version="1.1"
$revision="###VERSION###"

def help

STDERR.puts <<EOF
----------------------------
mgpmetis.rb version #{$version}
----------------------------
概要) METISを利用したグラフ分割(クラスタリング)
特徴) 1) 節点数をできるだけ同じようにして、枝のカット数を最小化するように分割する。
      2) 節点と枝に重みを与えることも可能。
      3) 一つの節点が複数のクラスタに属することはない(ハードクラスタリング)。
      4) 内部ではgpmetisコマンドをコールしている。
用法) mgpmetis.rb kway= [ptype=rb|kway] ei= [ef=] [ew=] [ni=] [nf=] [nw=] [o=]
                  [balance=] [ncuts=] [dat=] [map=] [-noexe] [--help]

  ファイル関連
  ei=      : 枝ファイル名(節点ペア)【必須】
  ef=      : 枝ファイル上の節点ペア項目名(2項目のみ)【デフォルト:"node1,node2"】
  ew=      : 枝ファイル上の重み項目名(1項目のみ)【オプション:省略時は全ての枝の重みを1と見なす】
           : 重みは整数で指定しなければならない。
  ni=      : 節点ファイル名【オプション*注1】
  nf=      : 節点ファイル上の節点項目名(1項目のみ)【デフォルト:"node"】
  nw=      : 節点ファイル上の重み項目名(複数項目指定可)【オプション:省略時は全ての重みを1と見なす】
           : 重みは整数で指定しなければならない。
  o=       : 出力ファイル名【オプション:defaultは標準出力】

  動作の制御関連
  kway=    : 分割数【必須】
  ptype=   : 分割アルゴリズム【デフォルト:kway】
  balance= : 分割アンバランスファクタ【デフォルト: ptype=rbの時は1.001、ptype=kwayの時は1.03】
  ncuts=   : 分割フェーズで、初期値を変えて試行する回数【オプション:default=1】
  seed=    : 乱数の種(0以上の整数)【オプション:default=-1(時間依存)】

  gpmetis用のデータ生成
  dat=     : 指定されたファイルにgpmetisコマンド用のデータを出力する。
  map=     : 指定されたファイルにgpmetisコマンド用の節点番号とi=上の節点名のマッピングデータを出力する。
  -noexe   : 内部でgpmetisを実行しない。dat=,map=の出力だけが必要な場合に指定する。

  その他
	--help   : ヘルプの表示

  注1：節点ファイルは、孤立節点(一つの節点からのみ構成される部分グラフ)がある場合、
       もしくは節点の重みを与えたいときのみ指定すればよい。
  注2：節点もしくは枝の重みを与えない時は、内部的に全ての重みを1として計算する。

必要なソフトウェア)
  gpmetis(metis-5.1.0)
  インストールは以下のURLより行う。
  http://glaros.dtc.umn.edu/gkhome/metis/metis/download

入力データ)
  節点ペアのCSVファイル(ファイル名はei=にて指定)
	例:
    node1,node2,weight
    a,b,1
    a,c,2
    a,e,1
    b,c,2
    b,d,1
    c,d,2
    c,e,3
    d,f,2
    d,g,5
    e,f,2
    f,g,6


出力データ)
  節点とクラスタ番号のCSVデータ(ファイル名はo=にて指定)
    node,cluster
    a,2
    b,1
    c,2
    d,0
    e,0
    f,0
    g,1

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

args=MCMD::Margs.new(ARGV,"ei=,ef=,ew=,ni=,nf=,nw=,o=,kway=,ptype=,balance=,ncuts=,dat=,map=,-noexe,seed=,T=,-verbose,T=","kway=,ei=")

# mcmdのメッセージは警告とエラーのみ
ENV["KG_VerboseLevel"]="2" unless args.bool("-verbose")
ENV["KG_ScpVerboseLevel"]="3" unless args.bool("-verbose")

# コマンド実行可能確認
CMD_gpmetis="gpmetis"
exit(1) unless(MCMD::chkCmdExe(CMD_gpmetis,"wc",120))

#ワークファイルパス
if args.str("T=")!=nil then
	ENV["KG_TmpPath"] = args.str("T=").sub(/\/$/,"")
end

kway   =args.int("kway=")
ofile  =args.file("o=","w")
efile  =args.file("ei=","r")
nfile  =args.file("ni=","r")
dfile  =args.file("dat=","o")
mfile  =args.file("map=","o")

# ---- edge field names (two nodes) on ei=
ef1,ef2 = args.field("ef=", efile, "node1,node2",2,2)["names"]

# ---- field name for edge weight
ew = args.field("ew=", efile, nil, 1,1)
ew = ew["names"][0] if ew

# ---- node field name on ni=
nf = args.field("nf=", nfile, "node")
nf = nf["names"][0] if nf

# ---- field names for node weights on ni=
nw = args.field("nw=", nfile)
ncon=0
if nw then
	ncon=nw["names"].size
	nw=nw["names"].join(",")
end

# ---- other paramters
ptype=args.str("ptype=","kway")
ncuts=args.int("ncuts=",1,1)
balance=args.float("balance=",nil,1.0)
ufactor=nil
if balance then
	ufactor=((balance-1.0)*1000).to_i
else
	if ptype=="kway"
		ufactor=30
	else
		ufactor=1
	end
end
seed=args.int("seed=",-1)
noexe =args.bool("-noexe")

# 本コマンドへの入力データイメージ
# node1,node2
# a,b
# a,c
# a,e
# b,c
# b,e
# b,g
# c,d
# c,g
# d,e
# e,f

# input file for gpmetis command
# first line: n m fmt ncon
# n: # of nodes
# m: # of edges
# fmt: 000(3 digits)
#   first  degit: node size? (always 0 in this command)
#   second degit: node weight is provided on the data
#   third  degit: edge weight is provided on the data
# 7 10    ( ノード数 エッジ数)
# 2 3 5   ( 1番ノードの接続ノード)
# 1 3 5 7 ( 2番ノードの接続ノード)
# 1 2 4 7
# 3 5
# 1 2 4 6
# 5
# 2 3

# gpmetisからの出力ファイルのイメージ
# 1  ( 1番ノードのクラスタ番号)
# 0  ( 2番ノードのクラスタ番号)
# 1
# 0
# 0
# 0
# 1

# 本コマンドの出力イメージ
# node,cluster
# a,1
# b,0
# c,1
# d,0
# e,0
# f,0
# g,1

# 一時ファイル
wf=MCMD::Mtemp.new

##########################################
# cleaning edge data (eliminate duplicate edge, add reverse directed edge for each existing edge)
xxedge   =wf.file
xxnode   =wf.file
xxnam2num=wf.file
xxnum2nam=wf.file
xxebase  =wf.file

xxe1     =wf.file
xxe2     =wf.file
f=""
if ew then
	f << "mcut f=#{ef1}:__node1,#{ef2}:__node2,#{ew}:__weight i=#{efile} |"
else
	f << "mcut f=#{ef1}:__node1,#{ef2}:__node2 i=#{efile} |"
end
f << "msortf   f=__node1,__node2 |"
f << "muniq    k=__node1,__node2 o=#{xxe1}"
system(f)
system "mfldname f=__node2:__node1,__node1:__node2 i=#{xxe1} o=#{xxe2}"

f=""
f << "mcat i=#{xxe1},#{xxe2} |"
f << "msortf f=__node1,__node2 |"
f << "muniq  k=__node1,__node2 o=#{xxedge}"
system(f)

# cleaning the node data (remove duplicate nodes)
if nfile then
	f=""
	if nw then
		f << "mcut   f=#{nf}:__node,#{nw} i=#{nfile} |"
	else
		f << "mcut   f=#{nf}:__node       i=#{nfile} |"
	end
	f << "msortf f=__node |"
	f << "muniq  k=__node o=#{xxnode}"
	system(f)
else
	xxeNode1 =wf.file
	xxeNode2 =wf.file
	system "mcut f=__node1:__node i=#{xxedge} o=#{xxeNode1}"
	system "mcut f=__node2:__node i=#{xxedge} o=#{xxeNode2}"
	f=""
	f << "mcat i=#{xxeNode1},#{xxeNode2} |"
	f << "msortf f=__node |"
	f << "muniq  k=__node o=#{xxnode}"
	system(f)
end

# 節点名<=>節点番号変換表の作成
f=""
f << "mcut    f=__node i=#{xxnode} |"
f << "mnumber a=__num S=1 -q o=#{xxnam2num}"
system(f)
system "msortf f=__num i=#{xxnam2num} o=#{xxnum2nam}"

# 節点ファイルが指定された場合は枝ファイルとの整合性チェック
if nfile then
	xxdiff=wf.file
	f=""
	f << "mcut f=__node1:__node i=#{xxedge} |"
	f << "muniq k=__node |"
	f << "mcommon -r k=__node m=#{xxnam2num} o=#{xxdiff}"
	system(f)
	tbl=MCMD::Mtable.new("i=#{xxdiff}")
	if tbl.size()>0 then
		raise "#ERROR# the node named `#{tbl.cell(tbl.name2num["__node"],0)}' in the edge file doesn't exist in the node file."
	end
end

# metisのグラフファイルフォーマット
# 先頭行n m [fmt] [ncon]
# n: 節点数、m:枝数、ncon: 節点weightの数
# 1xx: 節点サイズ有り (not used, meaning always "0")
# x1x: 節点weight有り
# xx1: 枝がweightを有り
# s w_1 w_2 ... w_ncon v_1 e_1 v_2 e_2 ... v_k e_k
# s: 節点サイズ  (節点サイズは利用不可)
# w_x: 節点weight
# v_x: 接続のある節点番号(行番号)
# e_x: 枝weight

# --------------------
# generate edge data using the integer numbered nodes
xxnnum=wf.file
xxenum=wf.file
f=""
f << "mcut   f=__num:__node_n1 i=#{xxnam2num} |"
f << "msortf f=__node_n1       o=#{xxnnum}"
system(f)

f=""
f << "mjoin  k=__node1 K=__node f=__num:__node_n1 m=#{xxnam2num} i=#{xxedge} |"
f << "msortf f=__node2 |"
f << "mjoin  k=__node2 K=__node f=__num:__node_n2 m=#{xxnam2num} |"
f << "msortf f=__node_n1 o=#{xxenum}"
system(f)

f=""
# this generates the isolated nodes
f << "mnjoin  k=__node_n1 m=#{xxenum} i=#{xxnnum} -n |"
f << "msortf f=__node_n1%n,__node_n2%n o=#{xxebase}"
system(f)
# xxebase
# __node1,__node2,__weight,__node_n1,__node_n2
# a,b,7,1,2
# a,c,8,1,3
# a,e,9,1,5

##########################################
# generate edge data for metis
xxebody  =wf.file
xxnbody  =wf.file
xxnbody1 =wf.file
xxwbody  =wf.file
xxbody   =wf.file
xxhead   =wf.file
xxgraph  =wf.file

unless ew then
	f=""
	f << "mcut   f=__node_n1,__node_n2   i=#{xxebase} |"
	f << "mtra   k=__node_n1 f=__node_n2 -q |"
	f << "mcut   f=__node_n2 -nfno o=#{xxbody}"
	system(f)

# if ew= is specified, merge the weight data into the edge data.
else
	f=""
	f << "mcut f=__node_n1,__node_n2:__v i=#{xxebase} |"
	f << "mnumber S=0 I=2 a=__seq -q     o=#{xxebody}"
	system(f)

	f=""
	f << "mcut f=__node_n1,__weight:__v  i=#{xxebase} |"
	f << "mnumber S=1 I=2 a=__seq -q     o=#{xxwbody}"
	system(f)

	f=""
	f << "mcat i=#{xxwbody},#{xxebody} |"
	f << "msortf f=__seq%n |"
	f << "mtra   k=__node_n1 f=__v -q |"
	f << "mcut   f=__v -nfno o=#{xxbody}"
	system(f)
end
# xxbody
# 2 7 3 8 5 9
# 1 7 3 10 5 11 7 12
# 1 8 2 10 4 13 7 14

# --------------------
# generate node data using integer number
if nfile and nw then
	# xxnode
	# __node,v1,v2
	# a,1,1
	# b,1,1
	# c,1,1
	f=""
	f << "msortf f=__node i=#{xxnode} |"
	f << "mjoin  k=__node f=__num m=#{xxnam2num} |"
	f << "msortf f=__num%n |"
	f << "mcut   f=#{nw} -nfno |"
	f << "tr ',' ' ' >#{xxnbody}" # tricky!!
	system(f)
	# xxnbody
	# 1 1
	# 1 1
	# 1 1
	# paste the node weight with edge body
	system "mpaste -nfn m=#{xxbody} i=#{xxnbody} | tr ',' ' ' >#{xxnbody1}"
	system "mv #{xxnbody1} #{xxbody}"
end
# xxbody
# 1 1 2 7 3 8 5 9
# 1 1 1 7 3 10 5 11 7 12
# 1 1 1 8 2 10 4 13 7 14

# 枝と節点のサイズ
eSize=MCMD::mrecount("i=#{xxedge}")
eSize/=2
nSize=MCMD::mrecount("i=#{xxnode}")

nwFlag=0
ewFlag=0
nwFlag=1 if nw
ewFlag=1 if ew
fmt="0#{nwFlag}#{ewFlag}"

system "echo '#{nSize} #{eSize} #{fmt} #{ncon}' > #{xxhead}"

system "cat #{xxhead} #{xxbody} > #{xxgraph}"

system "mfldname f=__num:num,__node:node i=#{xxnum2nam} o=#{mfile}" if mfile
system "cp #{xxgraph}   #{dfile}" if dfile

##########################################
## execute metis
unless noexe
	MCMD::msgLog "gpmetis -seed=#{seed} -ptype=#{ptype} -ncuts=#{ncuts} -ufactor=#{ufactor} #{xxgraph} #{kway}"
	if args.bool("-verbose") then
		system "gpmetis -seed=#{seed} -ptype=#{ptype} -ncuts=#{ncuts} -ufactor=#{ufactor} #{xxgraph} #{kway} "
	else
		system "gpmetis -seed=#{seed} -ptype=#{ptype} -ncuts=#{ncuts} -ufactor=#{ufactor} #{xxgraph} #{kway} > /dev/null"
	end

	if Dir["#{xxgraph}.part.*"].size == 0
		raise "#ERROR# command `gpmetis' didn't output any results"
	end

	# 節点名を数字から元に戻す
	# #{xxgraph}.part.#{kway}
	# 1
	# 0
	# 1
	f=""	
	f << "mcut    f=0:cluster -nfni i=#{xxgraph}.part.#{kway} |"
	f << "mnumber S=1 a=__num -q |"
	f << "msortf  f=__num |"
	f << "mjoin   k=__num f=__node m=#{xxnum2nam} |"
	f << "msortf  f=__node,cluster |"
	if nf then
		f << "mcut    f=__node:#{nf},cluster o=#{ofile}" 
	else
		f << "mcut    f=__node:node,cluster o=#{ofile}" 
	end
	system(f)
	# #{ofile}
	# n,cluster
	# a,1
	# b,0
	# c,1
end

# 終了メッセージ
MCMD::endLog(args.cmdline)

