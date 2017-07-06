#!/usr/bin/env ruby
#encoding:utf-8

require 'rubygems'
require 'nysol/mcmd'

# w=とclass=のバグ修正 20151209
$version=1.2
$revision="###VERSION###"


def help

STDERR.puts <<EOF
------------------------------
mnb.rb version #{$version}
------------------------------
概要) Naive Bayesを利用した分類器
特徴) 1) ベイズの定理による確率モデルを用いた教師あり学習の分類器
      2) アイテムの頻度情報を扱えるようにMultinominal Naive Bayesを利用
      3) ラプラススムージングによりゼロ頻度問題を調整(注1参照)
      4) complement Naive Bayesも利用可能
用法1) モデル構築モード
       mnb.rb [tid=] [item=] [w=] [class=] i= O= [seed=] [-complement] [-cv] [T=] [-mcmdenv] [--help]
用法2) 予測モード
       mnb.rb -predict i= I= o= [-complement] [T=] [--help]  [-mcmdenv]

例) mnb.rb tid=tid item=word w=freq class=class i=train.csv O=output seed=1 -cv
		mnb.rb tid=tid item=word w=freq i=test.csv I=output o=rsl_predict_model -predict

	## モデル構築モード
  i=          : 入力データのファイル名【必須】
  tid=        : 1つのサンプルを表す項目名【デフォルト:"tid"】
  item=       : 1つの変数を表す項目名【デフォルト:"item"】
  w=          : 変数の重み項目名 【オプション】
              : 指定しなければ、全行1とする。
  class=      : 目的変数の項目名(i=上の項目名)【デフォルト:"class"】
  seed=       : 乱数の種(0以上の整数,交差検証に影響)【オプション:default=-1(時間依存)】
  O=          : 出力ディレクト名 【必須】
  -complement : complement Naive Bayesで実行【オプション】
	-cv         : 交差検証の実施。デフォルトではテストサンプル法を実施

	その他
  T=          : 作業ディレクトリ【デフォルト:"/tmp"】
  -mcmdenv    : 内部のMCMDのコマンドメッセージを表示
  --help      : ヘルプの表示


	## 予測モード(-predict)
  I=          : モデル構築モードでの出力先ディレクトリパス 【必須】
  o=          : 予測結果出力ファイル名 [必須]
  i=          : 未知データのファイル名 [必須]
	tid=,item=,w= については、モデル構築モードと同じ項目名を持つ入力ファイルが必要である。

注1) ゼロ頻度問題は、テストで初めて出現したアイテムを含む場合に確率がゼロになる問題

利用例)
$ more train.csv
tid,item,freq,class
1,w1,2,M
1,w2,4,M
10,w1,1,F
11,w2,1,F
11,w1,2,F
12,w1,4,M
12,w2,4,M
13,w3,3,M
13,w2,2,M
13,w1,4,M
14,w1,5,M
14,w2,3,M
14,w3,2,M
15,w1,1,F
16,w1,2,F
16,w2,1,F
18,w2,4,F
18,w1,2,F
19,w2,2,F
19,w1,1,F
19,w3,3,F
2,w2,2,M
2,w1,3,M
2,w3,3,M
20,w1,1,F
20,w2,3,F
20,w3,2,F
4,w3,2,M
4,w2,3,M
4,w1,3,M
5,w1,1,F
6,w2,1,F
6,w1,1,F
7,w1,3,M
7,w2,4,M
8,w2,2,M
8,w3,3,M
8,w1,4,M
9,w1,3,M
9,w3,2,M
9,w2,3,M
17,w2,1,M
17,w1,2,M
3,w1,1,F
3,w2,1,F

$ mnb.rb tid=tid item=word w=freq class=class i=trainData.csv O=model seed=1
#MSG# separating data 1; 2014/08/18 12:17:38
#MSG# separating data 2; 2014/08/18 12:17:38
#MSG# separating data 3; 2014/08/18 12:17:38
#MSG# separating data 4; 2014/08/18 12:17:38
#MSG# separating data 5; 2014/08/18 12:17:38
#MSG# separating data 6; 2014/08/18 12:17:38
#MSG# separating data 7; 2014/08/18 12:17:38
#MSG# separating data 8; 2014/08/18 12:17:38
#MSG# separating data 9; 2014/08/18 12:17:38
#MSG# separating data 10; 2014/08/18 12:17:38
#MSG# Naive Bayes start using training data 1; 2014/08/18 12:17:38
#MSG# Naive Bayes start using test data 1; 2014/08/18 12:17:38
#END# ./mnb.rb tid=tid item=word w=freq class=class i=trainData.csv O=model seed=1; 2014/08/18 12:17:39
#MSG# Naive Bayes start using original data; 2014/08/18 12:17:39
#END# ./mnb.rb tid=tid item=word w=freq class=class i=trainData.csv O=model seed=1; 2014/08/18 12:17:39

$ more model/rsl_model.csv
tid,F,M,class,predictCls
1,0.5149523047,0.4850476955,M,F
10,0.4929065867,0.5070934133,F,M
11,0.5019607343,0.4980392657,F,F
12,0.5089038694,0.4910961304,M,F
13,0.4918393826,0.5081606174,M,M
14,0.4966021486,0.5033978514,M,M
15,0.4929065867,0.5070934133,F,M
...
...

Copyright(c) NYSOL 2012- All Rights Reserved.
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


def mktsData(ifile,oPath,ratio,seed)
  system "mkdir -p #{oPath}"

	f=""
	f << "msortf f=#{@cls},#{@tid} i=#{ifile} |"
	f << "msep d='#{oPath}/xxts-${class}'"
	system(f)
	
	# class毎に分けたファイルからratioの件数分ランダムに選択
	Dir::glob("#{oPath}/xxts-*").each {|ef|

		fName=File::basename("#{ef}") #ファイル名
		f=""
		f << "mselrand k=tid p=#{ratio} -B S=#{seed} i=#{ef} o=#{oPath}/xxtest-#{fName} u=#{oPath}/xxtrain-#{fName}"
    system(f)

	}
	system "mcat i=#{oPath}/xxtest-* o=#{oPath}/1_test.csv"
	system "mcat i=#{oPath}/xxtrain-* o=#{oPath}/1_train.csv"

	system "rm #{oPath}/xxt*"
end

def mkcvData(train,oPath,foldNum,seed)

	keyCnt=nil
  system "mkdir -p #{oPath}"

  #clsを分けるためにfold数にあわせてcls番号をふる
  if @tid # 縦型のデータ形式の場合
    system "msortf f=#{@tid} i=#{train} o=#{@wf}-xx1"
    system "mrand k=#{@tid} a=rand S=#{seed} i=#{@wf}-xx1 o=#{@wf}-rand"
    # クラス別件数のカウント
    f=""
    f << "muniq k=#{@tid} i=#{@wf}-xx1 |"
    f << "msortf f=#{@cls} |mcount k=#{@cls} a=keyCnt o=#{@wf}-keyCnt"
    system(f)

		keyCnt=`msortf f=keyCnt%n i=#{@wf}-keyCnt |mbest -q |mcut f=keyCnt -nfno |more`
		if keyCnt.to_i < foldNum
  		MCMD::errorLog("#{File.basename($0)}: the number of tid is less than the number of fold")
			exit
		end
  end

  f=""
  f << "msortf f=#{@cls},rand i=#{@wf}-rand |"
	# class別のキー番号
  f << "mnumber k=#{@cls} s=#{@cls},rand S=1 a=keyLine e=same |"
  f << "mjoin k=#{@cls} f=keyCnt m=#{@wf}-keyCnt |"
  f << "mcal c='ceil(${keyLine} / (${keyCnt} / #{foldNum}+0.00001),1)' a=val o=#{@wf}-xx2 "
  system(f)

  # クラス番号に合わせてファイルを出力
  (1..foldNum).each{|loop|
    MCMD::msgLog("separating data #{loop}")
    system "msel c='${val} == #{loop}' i=#{@wf}-xx2 u=#{@wf}-train-#{loop} o=#{@wf}-test-#{loop}"
  }

  (1..foldNum).each{|loop|
    system "mcut -r f=rand,keyLine,keyCnt,val i=#{@wf}-train-#{loop} o=#{oPath}/#{loop}_train.csv"
    system "mcut -r f=rand,keyLine,keyCnt,val i=#{@wf}-test-#{loop}  o=#{oPath}/#{loop}_test.csv"
  }

system "rm #{@wf}-*"
end


def mkCompliData(input)
	# ワード件数
	f=""
	f << "mcut f=#{@item},#{@w} i=#{input} |"
	f << "msortf f=#{@item} |"
	f << "msum k=#{@item} f=#{@w}:totalWord o=#{@wf}-xxtotalWord"
	system(f)

	# クラス別ワード別補集合の件数
	f=""
	f << "msortf f=#{@item},#{@cls} i=#{input} |"
	f << "msum k=#{@item},#{@cls} f=#{@w}:wCnt o=#{@wf}-xxfreq"
	system(f)
	f=""
	f << "mjoin -n k=#{@item},#{@cls} f=wCnt m=#{@wf}-xxfreq i=#{@wf}-xxwordClass |"
	f << "mnullto f=wCnt v=0 |"
	f << "msortf f=#{@item} |"
	f << "mjoin k=#{@item} f=totalWord m=#{@wf}-xxtotalWord |"
	f << "mcal c='${totalWord}-${wCnt}' a=compWcnt |"
	f << "mcut f=#{@item},#{@cls},compWcnt:wCnt |"
	f << "mfldname -q o=#{@wf}-xxsum"
	system(f)
end

def mkNormalData(input)
	# クラス別ワード別件数
	f=""
	f << "msortf f=#{@item},#{@cls} i=#{input} |"
	f << "msum k=#{@item},#{@cls} f=#{@w}:wCnt o=#{@wf}-xxfreq"
	system(f)
	f=""
	f << "mjoin -n k=#{@item},#{@cls} f=wCnt m=#{@wf}-xxfreq i=#{@wf}-xxwordClass |"
	f << "mnullto f=wCnt v=0 |"
	f << "mcut f=#{@item},#{@cls},wCnt |"
	f << "mfldname -q o=#{@wf}-xxsum"
	system(f)
end

def calAcc(input,outdir,oname)
  system "mcount a=totalCnt i=#{input} o=#{@wf}-xxtotalCnt"
  f=""
  f << "mcal c='if($s{#{@cls}}==$s{predictCls},\"Match\",\"Unmatch\")' a=ans i=#{input} |"
  f << "msortf f=ans |"
  f << "mcount k=ans a=cnt |mproduct f=totalCnt m=#{@wf}-xxtotalCnt |"
  f << "mcal c='${cnt}/${totalCnt}' a=accRate |"
  f << "mcut f=ans,cnt,totalCnt,accRate |"
	f << "mfldname -q o=#{outdir}/rsl_acc_#{oname}"
  system(f)
end


def calAccAvg(outdir,type)

	f=""
	f << "mcat i=#{outdir}/rsl_acc_*_#{type}.csv -add_fname |"
	f << "mselstr f=ans v=Match |"
	f << "msed f=fileName c=\"/.*/\" v=\"\" |"
	f << "msed f=fileName c=\"rsl_acc_\" v="" |"
	f << "msed f=fileName c=_test.csv v="" |"
	f << "mcut f=fileName:test,ans,cnt,totalCnt,accRate |"
	f << "mfldname -q o=#{outdir}/acclist.csv"
	system(f)
	system "mavg f=accRate i=#{outdir}/acclist.csv |mcut f=accRate |mfldname -q o=#{outdir}/acc.csv"

	system "rm #{outdir}/rsl_acc_*_*.csv"

end

def writeParam(temp,ifile,oPath,tid,item,w,cls,complement,ts,foldNum,seed)
	fw = open("#{oPath}/param.csv", "w")
	fw.puts "param,val"
	fw.puts "i=,#{ifile}"
	fw.puts "O=,#{oPath}"
	fw.puts "tid=,#{tid}"
	fw.puts "item=,#{item}"
	fw.puts "w=,#{w}"
	fw.puts "class=,#{cls}"
	fw.puts "-complement,#{complement}"
	fw.puts "ts=,#{ts}"
	foldNum=nil if foldNum==1
	fw.puts "cv=,#{foldNum}"
	fw.puts "seed=,#{seed}"
	fw.puts "T=,#{temp}"
	fw.close	
end


def run(input,output,odir,complement,trainFlg)

	if trainFlg # モデル構築時のみ実行

		# ワードとクラスの全組み合わせを生成
		system "mcut f=#{@item} i=#{input} |msortf f=#{@item} |muniq k=#{@item} o=#{@wf}-xxword"
		system "mcut f=#{@cls} i=#{input} |msortf f=#{@cls} |muniq k=#{@cls} o=#{@wf}-xxclass"
		system "mproduct f=#{@cls} m=#{@wf}-xxclass i=#{@wf}-xxword o=#{@wf}-xxwordClass"
	
		if complement
			mkCompliData(input)
		else
			mkNormalData(input)
		end
	
		# クラス別合計数
		f=""
		f << "mcut f=#{@cls},wCnt i=#{@wf}-xxsum |"
		f << "msortf f=#{@cls} |"
		f << "msum k=#{@cls} f=wCnt:total |"
		f << "mcut f=total,#{@cls} |"
		f << "mfldname -q o=#{@wf}-xxtotal"
		system(f)
	
		# スムージングのために全ワード種類数を計算
		f=""
		f << "mcut f=#{@item} i=#{input} |"
		f << "msortf f=#{@item} |"
		f << "muniq k=#{@item} |"
		f << "mcount a=wCategory |"
		f << "mcut f=wCategory o=#{@wf}-xxcategory"
		system(f)

		# クラスの出現確率Pr[c]を計算 (各クラスのID数/全ID件数)
		f=""
		f << "mcut f=#{@tid},#{@cls} i=#{input} |"
		f << "msortf f=#{@cls},#{@tid} |muniq k=#{@cls},#{@tid} o=#{@wf}-xx1"
		system(f)
		system "mcount a=totalId i=#{@wf}-xx1 o=#{@wf}-xxtotalID"
		f=""
		f << "mcount k=#{@cls}  a=memberNum i=#{@wf}-xx1 |"
		f << "mproduct f=totalId m=#{@wf}-xxtotalID |"
		f << "mcal c='ln(${memberNum}/${totalId})' a=prob |"
		f << "mcut -r f=#{@tid} |"
		f << "mfldname -q o=#{@wf}-xxprob"
		system(f)

		# クラス別ワード件数を予測データ用に保存
		system "cp #{@wf}-xxsum   #{odir}/clsWord.csv"
		system "cp #{@wf}-xxtotal #{odir}/totalCnt.csv"
		system "cp #{@wf}-xxprob  #{odir}/clsProb.csv"
		system "cp #{@wf}-xxcategory #{odir}/category.csv"
	end
	
	f=""
	f << "mproduct f=wCategory m=#{odir}/category.csv i=#{input} |"
	f << "msortf f=#{@item} |"
	if trainFlg # 訓練データ実行中
		f << "mnjoin k=#{@item} f=wCnt,#{@cls}:keyCls m=#{@wf}-xxsum |"
		f << "msortf f=keyCls |"
		f << "mnjoin k=keyCls K=#{@cls} f=total m=#{@wf}-xxtotal |"
		f << "msortf f=#{@tid},#{@item},#{@cls} o=#{@wf}-xxdat"
	else	      # 予測データ実行中
		f << "mnjoin k=#{@item} f=wCnt,#{@cls}:keyCls m=#{odir}/clsWord.csv |"
		f << "msortf f=keyCls |"
		f << "mnjoin k=keyCls K=#{@cls} f=total m=#{odir}/totalCnt.csv |"
		f << "msortf f=#{@tid},#{@item} o=#{@wf}-xxdat"
	end
	system(f)
	
	# xxdat
	# id,word,freq,class,wCategory,wCnt,keyCls,total
	# 1,w1,2,M,3,4,F,30
	# 1,w1,2,M,3,6,M,30
	# 1,w2,4,M,3,4,F,30
	# 1,w2,4,M,3,17,M,30
	# 1,w3,0,M,3,7,M,30
	# 1,w3,0,M,3,0,F,30
	# 2,w1,1,M,3,6,M,30
	# 2,w1,1,M,3,4,F,30
	# 2,w2,2,M,3,17,M,30
	#
	# データの意味: ex.)1行目
	# id1(文章1)のclassはMで,文章中にw1という語が2回出現し、語の出現種類数は3である
	# F(keyCls)に属する文章の中で語w1は４回出現している。classMの総出現語数は30
	# 
	# 上記のデータを用いて
	# argmax c = Ln Pr[c]+Σx_ij Ln(θcj)を計算

	# Pr[c] (各クラスのID数/全ID件数)は計算済み
	# Σx_ij Ln(θcj)を計算
	f=""
	f << "msortf f=keyCls i=#{@wf}-xxdat |"
	if trainFlg # 訓練データ実行中
		f << "mjoin k=keyCls K=#{@cls} f=prob m=#{@wf}-xxprob |"
	else
		f << "mjoin k=keyCls K=#{@cls} f=prob m=#{odir}/clsProb.csv |"
	end
	f << "mcal c='${#{@w}}*ln((${wCnt}+1)/(${total}+${wCategory}))' a=2term |"
	f << "msortf f=#{@tid},keyCls,#{@item} |"
	f << "msum k=#{@tid},keyCls f=2term:sumVal |"
	f << "mcal c='${prob}+${sumVal}' a=probCls o=#{@wf}-xxprobCls"
	system(f)
	
	f=""
	if complement # 属さない確率が最も低いものを選択
		f << "msortf f=#{@tid},probCls%n i=#{@wf}-xxprobCls |"
	else          # 属す確率が最も高いものを選択
		f << "msortf f=#{@tid},probCls%nr i=#{@wf}-xxprobCls |"
	end
	f << "mbest k=#{@tid} -q R=1 |"
	if trainFlg # 訓練データ実行中
		f << "mcut f=#{@tid},#{@cls},keyCls:predictCls o=#{@wf}-xx#{output}"
	else
		f << "mcut f=#{@tid},keyCls:predictCls o=#{@wf}-xx#{output}"
	end
	system(f)

	# 出力
	f=""
	f << "mcut f=#{@tid},keyCls,probCls i=#{@wf}-xxprobCls |"
	f << "msum k=#{@tid} f=probCls:sumProb o=#{@wf}-xxProbagg"
	system(f)

	f=""
	f << "mjoin k=#{@tid} f=sumProb m=#{@wf}-xxProbagg i=#{@wf}-xxprobCls |"
	f << "mcal c='if(${sumProb}<0,1-(${probCls}/${sumProb}),${probCls}/${sumProb})' a=probability |"
	f << "mcut f=#{@tid},keyCls,probability |"
	f << "mcross k=#{@tid} f=probability s=keyCls |mcut -r f=fld o=#{@wf}-xxcross"
	system(f)

	f=""
	if trainFlg # 訓練データ実行中
		f << "mjoin k=#{@tid} f=#{@cls},predictCls m=#{@wf}-xx#{output} i=#{@wf}-xxcross |"
		f << "mfldname -q o=#{odir}/#{output}"
	else
		f << "mjoin k=#{@tid} f=predictCls m=#{@wf}-xx#{output} i=#{@wf}-xxcross |"
		f << "mfldname -q o=#{odir}/#{output}"
	end
	system(f)

	unless ARGV.index("-predict")  
		ifile=File.basename(input) # ファイル名抽出
		calAcc("#{odir}/#{output}","#{odir}","#{ifile}") # 正解率 = 正解した評価事例数 / 評価事例数
	end

system "rm #{@wf}-*"
end

##################################
# model predict mode
##################################
if ARGV.index("-predict")
#args=MCMD::Margs.new(ARGV,"i=,I=,o=,item=,tid=,w=,class=,T=,-complement,-mcmdenv,-predict","i=,I=")
args=MCMD::Margs.new(ARGV,"i=,I=,o=,w=,T=,-complement,-verbose,-predict","i=,I=,o=")

# mcmdのメッセージは警告とエラーのみ
ENV["KG_VerboseLevel"]="2"    unless args.bool("-verbose")
ENV["KG_ScpVerboseLevel"]="3" unless args.bool("-verbose")

#ワークファイルパス
if args.str("T=")!=nil then
  @temp = args.str("T=").sub(/\/$/,"")
else
	@temp="/tmp"
end

@wf="#{@temp}/mcmd-mnb"

ifileBase = args.file("i=","r")
iPath = args.file("I=","r")
ofile = args.file("o=","w")

mcomplement=nil
# モデル構築時のパラメータチェック
MCMD::Mcsvin.new("i=#{iPath}/param.csv"){|csv|
  csv.each{|val|
			@tid  =val["val"] if val["param"] == "tid="
			@item =val["val"] if val["param"] == "item="
			@w    =val["val"] if val["param"] == "w="
			@cls  =val["val"] if val["param"] == "class="
			mcomplement  =val["val"] if val["param"] == "-complement"
  }
}

if @w=="unit"
	system "msetstr v=1 a=#{@w} i=#{ifileBase} o=#{@wf}_testFile"
	ifile="#{@wf}_testFile"
else
	ifile="#{ifileBase}"
end

# -complement オプション
complement=args.bool("-complement")

# model構築時のcomplementオプションの有無と異なる場合はERROR
if mcomplement.to_s != complement.to_s
  MCMD::errorLog("#{File.basename($0)}: The complement option is different from usage of the model construction")
  exit
end


if complement # complement naiveBaysの実行
  MCMD::msgLog("Complemt Naive Bayes start using test data")
	run(ifile,"#{ofile}",iPath,complement,nil) 
	MCMD::endLog("#{$0} #{args.argv.join(' ')}")
else               # naiveBaysの実行
 	MCMD::msgLog("Naive Bayes start using test data") 
	run(ifile,"#{ofile}",iPath,complement,nil) 
	MCMD::endLog("#{$0} #{args.argv.join(' ')}")
end


##################################
# model building mode
##################################
else
# パラメータ設定
args=MCMD::Margs.new(ARGV,"i=,O=,-complement,item=,tid=,w=,class=,seed=,cv=,ts=,T=,-verbose","i=,O=")

# mcmdのメッセージは警告とエラーのみ
ENV["KG_VerboseLevel"]="2"    unless args.bool("-verbose")
ENV["KG_ScpVerboseLevel"]="3" unless args.bool("-verbose")

#ワークファイルパス
if args.str("T=")!=nil then
  @temp = args.str("T=").sub(/\/$/,"")
else
	@temp="/tmp"
end

ifileBase = args.file("i=","r")
oPath = args.file("O=", "w")
system "mkdir -p #{oPath}"

# o=モデルの出力ファイル名
ofile ="rsl_model.csv"

# ---- tid field names
@tid  = args.field("tid=" , ifileBase, "tid" , 1,1)["names"][0]

# ---- field name
@item = args.field("item=", ifileBase, "item", 1,1)["names"][0]

@cls = args.field("class=", ifileBase, "class", 1,1)["names"][0]

@wf="#{@temp}/mcmd-mnb"

@w = args.field("w=", ifileBase, nil, 1,1)
if @w # 重みが指定
	@w = @w["names"][0] 
	ifile="#{ifileBase}"
else # 1の重みをつける
	@w = "unit"
	system "msetstr v=1 a=#{@w} i=#{ifileBase} o=#{@wf}_input"
	ifile="#{@wf}_input"
end


# -complement オプション
complement=args.bool("-complement") #->true

# ts= オプション
# paraにts=が指定された場合は,ts=0.0
# paraにts=がない場合は,ts=nil
# paraにts=10が指定された場合は,ts=10.0
ts=args.float("ts=")

# cv= オプション
foldNum=args.int("cv=")

# 乱数の種
seed =args.int("seed=", -1)


if ts
	ts=33.3 if ts == 0.0  # パラメータにts=だけが指定された場合は0.0
	mktsData(ifile,"#{@temp}",ts,seed)
	foldNum=1 # テストサンプル法なので1回だけ実行

elsif foldNum
	# cv用にデータ・セットを生成
	foldNum=10 if foldNum == 0
	mkcvData(ifile,"#{@temp}",foldNum,seed)
else  # 入力データを全て訓練データとみなす
	system "cp #{ifile} #{@temp}/1_train.csv"
	system "cp #{ifile} #{@temp}/1_test.csv"
	foldNum=1 # 訓練データを全て利用するので1回だけ実行
end

writeParam(@temp,ifile,oPath,@tid,@item,@w,@cls,complement,ts,foldNum,seed)

(1..foldNum).each{|loop| 
  traFile ="#{@temp}/#{loop}_train.csv"
  testFile="#{@temp}/#{loop}_test.csv"

	if complement # complement naiveBaysの実行
 	 MCMD::msgLog("Complemt Naive Bayes start using training data #{loop}")
		run(traFile,ofile,oPath,complement,"true")   # 訓練
 	 MCMD::msgLog("Naive Bayes start using test data #{loop}")
		run(testFile,ofile,oPath,complement,"false") # 検証
	 MCMD::endLog("#{$0} #{args.argv.join(' ')}")
	else         # naiveBaysの実行
 	 MCMD::msgLog("Naive Bayes start using training data #{loop}")
		run(traFile,ofile,oPath,complement,"true")   # 訓練
 	 MCMD::msgLog("Naive Bayes start using test data #{loop}")
		run(testFile,ofile,oPath,complement,"false") # 検証
	 MCMD::endLog("#{$0} #{args.argv.join(' ')}")
	end
}

calAccAvg(oPath,"test")

# 元データでモデル構築
if complement # complement naiveBaysの実行
MCMD::msgLog("Complement Naive Bayes start using original data")
run(ifile,ofile,oPath,complement,"true")
MCMD::endLog("#{$0} #{args.argv.join(' ')}")
else
MCMD::msgLog("Naive Bayes start using original data")
run(ifile,ofile,oPath,complement,"true")
MCMD::endLog("#{$0} #{args.argv.join(' ')}")
end

system "rm #{@temp}/*_train.csv"
system "rm #{@temp}/*_test.csv"
end
