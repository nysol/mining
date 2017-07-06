#!/usr/bin/env ruby
# encoding: utf-8

# 1.0 initial development: 2015/02/03
# 1.1 multi-processing: 2015/03/01
# 1.2 bug fix (0 division, sequence) : 2015/03/01
$version="1.2"
$revision="###VERSION###"

def help

STDERR.puts <<EOF
----------------------------
mnetsimile.rb version #{$version}
----------------------------
概要) NetSimileによるグラフ特徴量の計算および複数グラフの類似度計算
特徴) 1) グラフの全節点について7つの特徴量を計算する。
      2) 全接点の7つの特徴量について5つの統計量(中央値,平均,標準偏差,歪度,尖度)を計算しグラフの特徴量(35次元ベクトル)とする。
      3) グラフ間類似度を上記35次元ベクトルのcanberraDistanceにより定義する。*注1)
      4) 指定した全グラフペアの類似度を出力する。

参考文献) M. Berlingerio, D. Koutra, T. Eliassi-Rad, and C. Faloutsos,
          “Netsimile: A scalable approach to size-independent network similarity,” CoRR, vol. abs/1209.2684, 2012.

用法) mnetsimile.rb i=|I= O= mode=sequence|allpairs|features -edge [T=] [-mcmdenv] [--help]
  I=      : 複数のグラフファイルを格納したディレクトリパス【必須】*注2)
  nf=     : 節点データ上の節点項目名(省略時は"node")
  ef=     : 枝データ上の2つの節点項目名(省略時は"node1,node2")
  O=      : 出力パス【必須】
  mode=   : 動作モード【オプション】
          : sequence : ファイル名のアルファベット順のグラフシーケンスとして見なし
          :            隣り合うグラフ同士のみを比較する。
          : allpairs : 全グラフペアを比較する。
          : features : 各グラフの特徴量のみ出力し、グラフ間の類似度は計算しない。
	-edge   : 節点ファイルは利用せず、枝ファイルのみを利用する(I=のディレクトリに節点ファイルはなくてもよい)

  ## その他
	T=       : 作業ディレクトリ【デフォルト:"/tmp"】
	-mcmdenv : 内部のMCMDのコマンドメッセージを表示
	--help   : ヘルプの表示

  *注1) グラフ間類似度(P,Q)=1.0-canberraDistance(P,Q)= 1.0 - sum_i^d \frac{|P_i-Q_i|}{(|P_i|+|Q_i|}
  *注2) グラフファイルは節点ファイルと枝ファイルによって指定する。
        それぞれファイルの拡張子は".node"、".edge"でなければならない。

必要なソフトウェア)
  1) R
  2) Rのigraphパッケージ

入力データ)
	例: graphsディレクトリ内の4ファイル
    g1.edge      g1.node  g2.edge     g2.node
    node1,node2  node     node1,node2 node   
    E,J          A        E,J         A      
    E,A          B        E,A         B      
    J,D          C        J,D         C      
    J,A          D        J,A         D      
    J,H          E        J,H         E      
    D,H          F        D,H         F      
    D,F          G        H,F         G      
    H,F          H        A,F         H      
    A,F          I        B,H         I      
    B,H          J                    J

# 以下のコマンドを実行することで得られる出力ファイル群
$ mnetsimile.rb I=graphs O=result

出力データ1) グラフ別35の特徴量(7特徴量×5統計量)
  featruesGraph.csv (featureおよびstat項目の値の意味は後述)
    gid,feature,stat,value
    g1,cc,median,0.3333333333
    g1,cc,mean,0.4285714286
    g1,cc,usd,0.3170632437
    g1,cc,uskew,0.8631849195
    g1,cc,ukurt,1.244875346
    g1,ccN,median,0.3333333333
    g1,ccN,mean,0.4166666667
               :
    dat2,cc,median,0.3333333333
    dat2,cc,mean,0.4047619048
    dat2,cc,usd,0.4287918305
               :

    注) gid: グラフID(拡張子を除いたファイル名)

出力データ2) グラフ+節点別の7特徴量
  featruesNode.csv (feature項目の値の意味は後述)
    gid%0,fid,node%1,feature,value
    dat1,A_deg,A,deg,3
    dat1,A_cc,A,cc,0.333333333333333
    dat1,A_degN,A,degN,3
    dat1,A_ccN,A,ccN,0.555555555555556
               :
  注) fid項目は、node項目とfeature項目を結合した項目
  注) 孤立節点(他の節点と接続のない1つの節点)の特徴量は全て0と定義する。
      孤立節点を無視したければ-edgeオプションを指定して実行すれば良い。

出力データ3) グラフ間類似度行列
  similarity.csv(特徴量35次元ベクトルのcanberraSimilarity
    gid1,gid2,similarity
    dat1,dat2,0.6593442055

出力データ4) 7つの類似度について、グラフ間比較における有意確率(サンプルは節点)
  pvalue_ks.csv : two-sample Kolmogorov-Smirnov test (分布の差の検定)
    gid1,gid2,deg,cc,degN,ccN,eEgo,eoEgo,nEgo
    dat1,dat2,0.937502699053248,0.937502699053248,0.937502699053248,0.541243098374871,0.937502699053248,0.937502699053248,0.937502699053248

  pvalue_wx.csv : two-sample Wilcoxon test (中央値の差の検定)
    gid1,gid2,deg,cc,degN,ccN,eEgo,eoEgo,nEgo
    dat1,dat2,0.64316810166757,0.687070906822053,0.846328946368719,0.257155612551595,0.436141208362552,0.429488461717429,0.62639648401305

7つの特徴量の項目名:
   deg   : 次数
   cc    : クラスタ係数
   degN  : 近傍節点の平均次数
   ccN   : 近傍節点の平均クラスタ係数
   eEgo  : egoネットワークの枝数
   eoEgo : egoネットワークに接続された枝数
   nEgo  : egoネットワークに接続された節点数

   注) 詳細な定義は、上述の参考文献を参照のこと。

5つの統計量
  median : 中央値
  mean   : 平均
  usd    : 標準偏差
  uskew  : 歪度
  ukurt  : 尖度

例)
  $ mnetsimile.rb I=graphs O=result mode=sequence ef=v1,v2 nf=v

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

# Rライブラリ実行可能確認
exit(1) unless(MCMD::chkRexe("igraph"))

def genRtest(eFile,oFile,scpFile)
exit
end

def genRscript(eFile,oFile,scpFile)
	r_proc = <<EOF
library(igraph)
## reading edge file
g=read.graph("#{eFile}",format="edgelist",directed=FALSE)

#### (1) d_i : degree of node_i
deg=degree(g)

#### (2) c_i : clustering coefficient of node_i
cc=transitivity(g,type="local",isolates="zero")

## neighbors list with order 1 or 2(1 hop or 2 hops) of node_i
nei1=neighborhood(g,order=1)
nei2=neighborhood(g,order=2)

## delete myself(first element) from the 1 hope list
delFirst=function(x){x[-1]}
nei1del=sapply(nei1,FUN=delFirst)

#### (3) d_{N(i)} : mean of degree for neighbors of node_i
f=function(x){mean(deg[unlist(x)])}
degN=sapply(nei1del,FUN=f)

#### (4) c_{N(i)} : mean of clustering coefficient for neighbors of node_i
f=function(x){mean(cc[unlist(x)])}
ccN=sapply(nei1del,FUN=f)

## get ego-network of node_i
f=function(x){induced.subgraph(g,vids=unlist(x))}
ego=lapply(nei1,FUN=f)

#### (5) E_{Ego(i)} : number of edges for egonetwork of node_i
eEgo=sapply(ego,FUN=ecount)

#### (6) E^o_{Ego(i)} : number of edges outgoing from egonetwork of node_i
f=function(x){
	# induced subgraph by 1 hop neighbor
	isg1=induced.subgraph(g,vids=unlist(nei1[x]))
	# induced subgraph by 2 hops neighbor
	isg2=induced.subgraph(g,vids=unlist(nei2[x]))
	# difference 2hops neighbor from 1 hop neighbor
	isgDiff=induced.subgraph(g,vids=setdiff(unlist(nei2[x]),unlist(nei1[x])))
	length(E(isg2))-length(E(isg1))-length(E(isgDiff))
}
eoEgo=sapply(rep(1:vcount(g)),FUN=f)

#### (7) N(Ego(i)) : number of nodes for neighbors of egonetwork_i
f=function(x){length(setdiff(unlist(nei2[x]),unlist(nei1[x])))}
nEgo=sapply(rep(1:vcount(g)),FUN=f)

dat=data.frame(deg=deg, cc=cc, degN=degN, ccN=ccN, eEgo=eEgo, eoEgo=eoEgo, nEgo=nEgo)
write.csv(dat,file="#{oFile}",quote=FALSE)
EOF

	File.open(scpFile,"w"){|fpw|
		fpw.write(r_proc)
	}
end

def conv2num(baseName,edgeFlg,numFile,mapFile,isoFile)
	nFile="#{baseName}.node"
	eFile="#{baseName}.edge"

	wf=MCMD::Mtemp.new
	xxn1=wf.file
	xxn2=wf.file
	xxn3=wf.file
	xxeNodeMF=wf.file

	# create a nodes list that are included in node and edge data
	system "mcut f=#{$ef1}:node i=#{eFile} o=#{xxn1}"
	system "mcut f=#{$ef2}:node i=#{eFile} o=#{xxn2}"
	if edgeFlg or not File.exists?(nFile)
		system "echo node >#{xxn3}"
	else
		system "mcut f=#{$nf}:node  i=#{nFile} o=#{xxn3}"
	end

	# xxeNodeMF : nodes list that are included in edge
	system "mcat i=#{xxn1},#{xxn2} | muniq k=node | msetstr v=1 a=eNode o=#{xxeNodeMF}"

	# isolate nodes list
	system "mcat i=#{xxn1},#{xxn2},#{xxn3} | mcommon k=node m=#{xxeNodeMF} -r o=#{isoFile}"

	# create a mapping table between the original node label and the number iGraph will use
	f=""
	f << "mcat i=#{xxn1},#{xxn2},#{xxn3} |"
	f << "muniq k=node |"
	f << "mjoin k=node m=#{xxeNodeMF} f=eNode |"
	f << "mnullto f=eNode v=0 |"
	f << "mnumber s=eNode%r,node a=nid o=#{mapFile}" 
	system(f)

	# create a data file that R script read
	f=""
	f << "mjoin k=#{$ef1} K=node m=#{mapFile} f=nid:nid1 i=#{eFile} |"
	f << "mjoin k=#{$ef2} K=node m=#{mapFile} f=nid:nid2 |"
	f << "mcut  f=nid1,nid2 -nfno |"
	f << "tr ',' ' ' >#{numFile}"
	system(f)
end


#################################################################################################
#### Entry point

args=MCMD::Margs.new(ARGV,"i=,I=,ef=,nf=,O=,mode=,-edge,mp=,T=,-verbose,T=","O=")

# mcmdのメッセージは警告とエラーのみ
ENV["KG_VerboseLevel"]="2" unless args.bool("-verbose")
ENV["KG_ScpVerboseLevel"]="3" unless args.bool("-verbose")

#ワークファイルパス
if args.str("T=")!=nil then
	ENV["KG_TmpPath"] = args.str("T=").sub(/\/$/,"")
end

iPath = args.file("I=","r")
oPath = args.file("O=","w")
mode  = args.str("mode=","allpairs")
# ---- edge field names (two nodes)
ef = args.str("ef=", "node1,node2")
ef = ef.split(",")
if ef.size!=2 then
	raise "#ERROR# ef= must take two field names"
end
$ef1=ef[0]
$ef2=ef[1]

# ---- node field name
nf = args.str("nf=","node")
$nf=nf

edgeFlg=args.bool("-edge")
$mp=args.int("mp=",1)

nfFile="#{oPath}/featuresNode.csv"
gfFile="#{oPath}/featuresGraph.csv"
MCMD::mkDir(oPath)

wf=MCMD::Mtemp.new
numFile=Array.new($mp)
mapFile=Array.new($mp)
scpFile=Array.new($mp)
feaFile=Array.new($mp)
isoFile=Array.new($mp)
isoFeatures=Array.new($mp)
xxtmp=Array.new($mp)

nfPath=Array.new($mp)
gfPath=Array.new($mp)

(0...$mp).each{|i|
	numFile[i]=wf.file
	mapFile[i]=wf.file
	scpFile[i]=wf.file
	feaFile[i]=wf.file
	isoFile[i]=wf.file

	isoFeatures[i]=wf.file
	nfPath[i]     =wf.file
	xxtmp[i]      =wf.file
	gfPath[i]     =wf.file

	MCMD::mkDir(nfPath[i])
	MCMD::mkDir(gfPath[i])
}


files = Dir["#{iPath}/*.edge"]
files.sort!  # 419行目のnames.sortと同じ順番を保証するため
files.meach($mp){|file,count,pno|

	MCMD::msgLog("START fearture extraction: #{file} #{pno} #{isoFeatures[pno]}")

	baseName=file.sub(/\.edge$/,"")
	name=baseName.sub(/^.*\//,"")

	conv2num(baseName,edgeFlg,numFile[pno],mapFile[pno],isoFile[pno])

	# isolate node
	f=""
	f << "msetstr v=#{name},0,0,0,0,0,0,0 a=gid,deg,cc,degN,ccN,eEgo,eoEgo,nEgo i=#{isoFile[pno]} |"
	f << "mcut f=gid,node:#{$nf},deg,cc,degN,ccN,eEgo,eoEgo,nEgo o=#{isoFeatures[pno]}"
	system(f)

	genRscript(numFile[pno], feaFile[pno],scpFile[pno])
	if args.bool("-verbose") then
		system "R --vanilla -q < #{scpFile[pno]} "
	else
		system "R --vanilla -q  --slave < #{scpFile[pno]} 2>/dev/null"
	end

	f=""
	f << "mnullto f=0 v=seq -nfn i=#{feaFile[pno]} |"
	f << "mcal c='${seq}-1' a=nid |"
	f << "mjoin k=nid f=node m=#{mapFile[pno]} |"
	f << "msetstr a=gid v=#{name} |"
	f << "mcut f=gid,node:#{$nf},deg,cc,degN,ccN,eEgo,eoEgo,nEgo o=#{nfPath[pno]}/#{name}"
	system(f)

	system "mcat i=#{nfPath[pno]}/#{name},#{isoFeatures[pno]} o=#{xxtmp[pno]}"
	system "cp #{xxtmp[pno]} #{nfPath[pno]}/#{name}"

	f=""
	f << "msummary c=median,mean,usd,uskew,ukurt f=deg,cc,degN,ccN,eEgo,eoEgo,nEgo i=#{nfPath[pno]}/#{name} |"
	f << "mfldname f=fld:feature |"
	f << "msetstr v=value a=value |"
	f << "mcross k=feature a=stat f=median,mean,usd,uskew,ukurt s=value |"
	f << "msetstr a=gid v=#{name} |"
	f << "mcut f=gid,feature,stat,value o=#{gfPath[pno]}/#{name}"
	system(f)

}

gfStr=[]
gfPath.each{|path| gfStr << "#{path}/*" }
nfStr=[]
nfPath.each{|path| nfStr << "#{path}/*" }

f=""
f << "mcat i=#{gfStr.join(',')} |"
f << "mcut f=gid,feature,stat,value |"
f << "msortf f=gid,feature,stat o=#{gfFile}"
system(f)

f=""
f << "mcat i=#{nfStr.join(',')} |"
f << "msetstr v=value a=value |"
f << "mcross k=gid,#{$nf} s=value a=feature f=deg,cc,degN,ccN,eEgo,eoEgo,nEgo |"
f << "mcal c='$s{#{$nf}}+\"_\"+$s{feature}' a=fid |"
f << "mcut f=gid,fid,#{$nf},feature,value |"
f << "msortf f=gid,fid,#{$nf},feature o=#{nfFile}"
system(f)

#↓現状つかわていない
def getFeatures(file)
	vector=[]
	MCMD::Mcsvin.new("i=#{file}"){|csv|
		csv.each{|flds|
			vector << flds["value"]
		}
	}
	return vector
end

features={}
names=[]
Dir.glob(gfStr).each{|file|
	name=file.sub(/^.*\//,"")
	vector=[]
	MCMD::Mcsvin.new("i=#{file}"){|csv|
		csv.each{|flds|
			vector << flds["value"].to_f
		}
	}
	if vector.size==35
		names << name
		features[name]=vector
	else
		MCMD::warningLog("internal warning: vector size must be 35, but #{vector.size} in file #{name}")
	end
}
names.sort!

def canberraSim(p,q)
	dist=0
	(0...p.size).each{|i|
		den=p[i].abs+q[i].abs
		num=(p[i]-q[i]).abs
		if den==0
			dist += 0
		else
			dist += num/den
		end
	}
	return 1.0-dist/p.size
end

#↓現状つかわていない
def svm(path,name1,name2)
	wf=MCMD::Mtemp.new
	xxds=wf.file
	xxscp=wf.file

	# gid,node,deg,cc,degN,ccN,eEgo,eoEgo,nEgo
	# 20000115,あう,39,0.777327935222672,104.384615384615,0.506364530021185,615,2880,538
	# 20000115,ある,253,0.0989397076353598,28.7786561264822,0.844456619367387,3407,720,325
	f=""
	f << "mcat i=#{path}/#{name1},#{path}/#{name2} |"
	f << "mcut f=gid,deg,cc,degN,ccN,eEgo,eoEgo,nEgo o=#{xxds}"
	system(f)

	r_proc = <<EOF
library(kernlab)
library(mlbench)
d=read.csv("#{xxds}")
y=d$gid
x=as.matrix(d[,2:8])
model=ksvm(x,y,type="C-svc",kernel="vanilladot",cross=3)
print(model)
str(model)
EOF

	File.open(xxscp,"w"){|fpw|
		fpw.write(r_proc)
	}

	system "R --vanilla -q < #{xxscp} "
exit
prob1=0.1
prob2=0.9
	return prob1,prob2
end

#↓現状つかわていない
def test(paths,name1,name2)
	wf=MCMD::Mtemp.new
	xxks=wf.file
	xxwx=wf.file
	xxscp=wf.file

	# gid,node,deg,cc,degN,ccN,eEgo,eoEgo,nEgo
	# 20000115,あう,39,0.777327935222672,104.384615384615,0.506364530021185,615,2880,538
	# 20000115,ある,253,0.0989397076353598,28.7786561264822,0.844456619367387,3407,720,325
	r_proc = <<EOF
## reading edge file
d1=read.csv("#{path}/#{name1}")
d2=read.csv("#{path}/#{name2}")

ks_deg  =ks.test(d1$deg  , d2$deg   ,exact=TRUE)
ks_cc   =ks.test(d1$cc   , d2$cc    ,exact=TRUE)
ks_degN =ks.test(d1$degN , d2$degN  ,exact=TRUE)
ks_ccN  =ks.test(d1$ccN  , d2$ccN   ,exact=TRUE)
ks_eEgo =ks.test(d1$eEgo , d2$eEgo  ,exact=TRUE)
ks_eoEgo=ks.test(d1$eoEgo, d2$eoEgo ,exact=TRUE)
ks_nEgo =ks.test(d1$nEgo , d2$nEgo  ,exact=TRUE)

wx_deg  =wilcox.test(d1$deg  , d2$deg   ,exact=TRUE)
wx_cc   =wilcox.test(d1$cc   , d2$cc    ,exact=TRUE)
wx_degN =wilcox.test(d1$degN , d2$degN  ,exact=TRUE)
wx_ccN  =wilcox.test(d1$ccN  , d2$ccN   ,exact=TRUE)
wx_eEgo =wilcox.test(d1$eEgo , d2$eEgo  ,exact=TRUE)
wx_eoEgo=wilcox.test(d1$eoEgo, d2$eoEgo ,exact=TRUE)
wx_nEgo =wilcox.test(d1$nEgo , d2$nEgo  ,exact=TRUE)

ks_dat=data.frame(deg=ks_deg$p.value, cc=ks_cc$p.value, degN=ks_degN$p.value, ccN=ks_ccN$p.value, eEgo=ks_eEgo$p.value, eoEgo=ks_eoEgo$p.value, nEgo=ks_nEgo$p.value)
wx_dat=data.frame(deg=wx_deg$p.value, cc=wx_cc$p.value, degN=wx_degN$p.value, ccN=wx_ccN$p.value, eEgo=wx_eEgo$p.value, eoEgo=wx_eoEgo$p.value, nEgo=wx_nEgo$p.value)
print(ks_dat)
write.csv(ks_dat,file="#{xxks}",quote=FALSE,row.names=FALSE)
write.csv(wx_dat,file="#{xxwx}",quote=FALSE,row.names=FALSE)
EOF

	File.open(xxscp,"w"){|fpw|
		fpw.write(r_proc)
	}

	system "R --vanilla -q < #{xxscp} "

	ksv=[]
	MCMD::Mcsvin.new("i=#{xxks}"){|csv| csv.each{|flds|
		ksv << name1
		ksv << name2
		ksv << flds["deg"]
		ksv << flds["cc"]
		ksv << flds["degN"]
		ksv << flds["ccN"]
		ksv << flds["eEgo"]
		ksv << flds["eoEgo"]
		ksv << flds["nEgo"]
	}}

	wxv=[]
	MCMD::Mcsvin.new("i=#{xxwx}"){|csv| csv.each{|flds|
		wxv << name1
		wxv << name2
		wxv << flds["deg"]
		wxv << flds["cc"]
		wxv << flds["degN"]
		wxv << flds["ccN"]
		wxv << flds["eEgo"]
		wxv << flds["eoEgo"]
		wxv << flds["nEgo"]
	}}
	return ksv,wxv
end

# skip calculation of similarity if mode=="features"
unless mode=="features" then
	MCMD::Mcsvout.new("o=#{oPath}/similarity.csv f=gid1,gid2,similarity"){|oCSV|
	MCMD::Mcsvout.new("o=#{oPath}/pvalues_ks.csv f=gid1,gid2,deg,cc,degN,ccN,eEgo,eoEgo,nEgo"){|ksCSV|
	MCMD::Mcsvout.new("o=#{oPath}/pvalues_wx.csv f=gid1,gid2,deg,cc,degN,ccN,eEgo,eoEgo,nEgo"){|wxCSV|
		(0...names.size-1).each{|i|
			(i...names.size).each{|j|
				next if i==j
				next if mode=="sequence" and i+1!=j
				MCMD::msgLog("START similarity calcuration: #{names[i]} and #{names[j]}")
				g1=features[names[i]]
				g2=features[names[j]]
				sim=canberraSim(g1,g2)
				#ks_pvalues,wx_pvalues=test(nfStr,names[i],names[j])
				#prob1,prob2=svm(nfPath,names[i],names[j])
				oCSV.write( [ names[i],names[j],sim ] )
				#ksCSV.write( ks_pvalues )
				#wxCSV.write( wx_pvalues )
			}
		}
	}}}
end

#wf.rm

# end message
MCMD::endLog(args.cmdline)

