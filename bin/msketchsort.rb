#!/usr/bin/env ruby
# encoding: utf-8

require 'rubygems'
require 'nysol/mcmd'
require 'nysol/mining'
require 'fileutils'


# 1.0: initial develpoment 2014/12/02
# 1.1: added the seed for org sketchsort and msketchsort  2015/10/24
# 1.2: added error process from sketchsort 2016/11/5
$version="1.2"

def help

STDERR.puts <<EOF
---------------------------------
msketchsort.rb version #{$version}
---------------------------------
概要) スケッチソートを利用した全ベクトルペアの距離計算
特徴) データに含まれる全ベクトル間の距離を高速に計算できる。
      窓を指定することで比較するベクトルの範囲を限定することができる。

書式) #{$cmd} e= tid= [dist=] [th=] [mr=] [wf=] [ws=] [dist=C|H] i= [o=] [--help]

e=    : ベクトルの各要素となる項目名【必須】ex) e=val1,val2,val3,val4
tid=  : ベクトルを識別するための項目名(i=上の項目名)【必須】
dist= : ベクトル間の距離計算の方法。(省略時は C が指定される)
        C (cosine distance): コサイン距離 (th=0-2)
        H (Haming distance): ハミング距離 (th=1- )
th=   : dist=で指定された距離計算について、ここで指定された値以下のペアを出力する。省略時は0.01が設定される。
mr=   : ペアを逃す確率を指定 (missing ratio) False Negative。省略時は0.00001が設定される。
wf=   : ウィンドウ項目。ex) 日付
ws=   : ウィンドウサイズの上限(0以上の整数)【0で制限なし,default:0】
        wfで指定した窓に含まれる全ペアを窓をずらしながら計算する。
i=    : 入力ファイル
o=    : 出力ファイル
seed= : 乱数の種(1以上の整数,default:1)
-uc   : データ点を0を中心に移動させない


例1: input1.csv
tid,val1,val2,val3,val4,val5
0,4,9,1,8,7
1,2,6,3,4,10
2,3,10,1,7,4
3,2,8,1,3,10
4,4,7,2,3,10
5,8,4,3,1,9
6,6,7,5,1,9
7,5,4,2,6,7
8,3,10,1,5,9
9,9,1,8,7,3
10,5,2,3,10,9
11,4,9,1,8,7

$ msketchsort.rb i=input1.csv tid=tid e=val1,val2,val3,val4,val5 o=out1.csv
SketchSort version 0.0.8
Written by Yasuo Tabei

deciding parameters such that the missing edge ratio is no more than 1e-05
decided parameters:
hamming distance threshold: 1
number of blocks: 4
number of chunks: 14
.
.
.

$ more out1.csv
distance,tid,tid2
5.96046e-08,0,11



例2: input2.csv
eCode,tgdate,term,val1,val2,val3,val4,val5
1990,20100120,0,4,9,1,8,7
2499,20100120,0,2,6,3,4,10
2784,20100120,0,3,10,1,7,4
3109,20100120,0,2,8,1,3,10
3114,20100120,0,4,7,2,3,10
6364,20100120,0,8,4,3,1,9
8154,20100120,0,6,7,5,1,9
8703,20100120,0,5,4,2,6,7
9959,20100120,0,3,10,1,5,9
1990,20100121,1,9,1,8,7,3
2499,20100121,1,5,2,3,10,9
2784,20100121,1,4,9,1,8,7
3594,20100122,2,4,9,1,8,7


$ msketchsort.rb i=input2.csv tid=eCode,tgdate e=val1,val2,val3,val4,val5 th=0.05 wf=term ws=1 o=out2.csv
SketchSort version 0.0.8
Written by Yasuo Tabei

deciding parameters such that the missing edge ratio is no more than 1e-05
decided parameters:
hamming distance threshold: 1
number of blocks: 4
number of chunks: 14
.
.
.

$ more out2.csv
distance,eCode,tgdate,eCode2,tgdate2
0,1990,20100120,2784,20100121
0,2784,20100121,3594,20100122


# Copyright(c) NYSOL 2012- All Rights Reserved.
EOF
exit
end

def ver()
  STDERR.puts "version #{$version}"
  exit
end

help() if ARGV[0]=="--help" or ARGV.size <= 0
ver()  if ARGV[0]=="--version"

args=MCMD::Margs.new(ARGV,"e=,tid=,dist=,th=,mr=,wf=,ws=,dist=,i=,o=,T=,seed=,-uc,","tid=,i=,e=")



# mcmdのメッセージは警告とエラーのみ
ENV["KG_VerboseLevel"]="2" unless args.bool("-mcmdenv")

#ワークファイルパス
if args.str("T=")!=nil then
  ENV["KG_TmpPath"] = args.str("T=").sub(/\/$/,"")
end

ifile = args.file("i=","r") 
ofile = args.file("o=","w")
elem  = args.str("e=")
tidH   = args.field("tid=",ifile)  # check field
tid   = args.str("tid=")
dist  = args.str("dist=","C")
th    = args.float("th=",0.01)
mr    = args.float("mr=",0.00001)
wfH    = args.field("wf=",ifile)  # check field
wf    = args.str("wf=")
ws    = args.int("ws=",0)
seed  = args.int("seed=",1)
uc    = args.bool("-uc")
@workf=MCMD::Mtemp.new

@pt=Time.now.to_i

if dist=="H" and th <1.0
  MCMD::errorLog("#{File.basename($0)}: The range of th= is different")
  exit
end

# convert the data for sketchport
def mkdata(ifile,elem,tid,wf)
  xx1=@workf.file
  xx2=@workf.file
  xxmap=@workf.file
  sdata=@workf.file


	ln="#{@pt}line"

	# make the line number
  system "mnumber S=0 a=#{ln} -q i=#{ifile} o=#{xx1}"

	if wf
  	system "mcut f=#{wf},#{tid},#{elem} i=#{xx1}  o=#{xx2}"
  	system "mcut f=#{ln},#{tid} i=#{xx1} o=#{xxmap}"
	else
		wf="#{@pt}wf" unless wf
		f=""
		f << "msetstr v=0 a=#{wf} i=#{xx1} |"  
  	f << "mcut f=#{wf},#{tid},#{elem} o=#{xx2}"
		system(f)
  	system "mcut f=#{ln},#{tid} i=#{xx1} o=#{xxmap}"
	end



	# make the data for sketchsort
	system "mcut f=#{wf},#{elem} -nfno i=#{xx2} |sed 's/,/ /g' >#{sdata}"


	return sdata,xxmap
end

def doSsort(sdata,ofile,map,ws,uc,th,dist,mr,tid,seed)
  xx3=@workf.file

	if dist=="C"
		distance="-cosdist" 
	elsif dist=="H"
		distance="-hamdist" 
	end

	if uc	
		status=NYSOL_MINING::run_sketchsort("-auto #{distance} #{th} -missingratio #{mr} -windowsize #{ws} -seed #{seed} #{sdata} #{xx3}")
  	#status=system "#{CMD_ss} -auto #{distance} #{th} -missingratio #{mr} -windowsize #{ws} -seed #{seed} #{sdata} #{xx3}"
  	puts "sketchsort -auto #{distance} #{th} -missingratio #{mr} -windowsize #{ws} -seed #{seed} #{sdata} #{xx3}"
	else
		status=NYSOL_MINING::run_sketchsort("-auto -centering #{distance} #{th} -missingratio #{mr} -windowsize #{ws} -seed #{seed} #{sdata} #{xx3}")
  	#status=system "#{CMD_ss} -auto -centering #{distance} #{th} -missingratio #{mr} -windowsize #{ws} -seed #{seed} #{sdata} #{xx3}"
  	puts "sketchsort -auto -centering #{distance} #{th} -missingratio #{mr} -windowsize #{ws} -seed #{seed} #{sdata} #{xx3}"
	end
	unless status 
		raise "#ERROR# checking sketchsort messages"
	end

	tmp=[]
	tid.split(",").each{|val |
 	  tmp << "#{val}:#{val}2"
	}
	tid2=tmp.join(",")


  f="" 
  f << "sed 's/ /,/g' <#{xx3} |"
  f << "mcut -nfni f=0:eline1,1:eline2,2:distance |"
	f << "mfsort f=eline* |"
  # 行番号に対応するtidを取得
  f << "mjoin k=eline1 K=#{@pt}line f=#{tid} m=#{map} |"
  f << "mjoin k=eline2 K=#{@pt}line f=#{tid2} m=#{map} |"
	f << "msortf f=eline1%n,eline2%n |"
  f << "mcut -r f=eline1,eline2 |"
	f << "msortf f=#{tid} |"
	f << "mfldname -q o=#{ofile}"
  system(f)


end

sdata,xxmap=mkdata(ifile,elem,tid,wf)

doSsort(sdata,ofile,xxmap,ws,uc,th,dist,mr,tid,seed)

MCMD::endLog(args.cmdline)
