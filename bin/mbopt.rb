#!/usr/bin/env ruby
# encoding: utf-8
require "rubygems"
require "nysol/mcmd"
require "json"

# 1.0: first release: 2015/2/22
# 1.1: bug fix in running by ruby 1.8: 2015/3/17
# 1.2: add seed= parameter : 2015/7/18
#    : bug fix in multi-processing mode
# 1.3: bug fix in building a null GP model : 2015/7/19
# 1.4: bug fix for directory path name and random seed: 2015/10/19
# 1.5: add log= parameter: 2015/11/22
# 2.0: change the order of parameters for optimization script: 2015/11/22
#    : add continue mode,
#    : change a default value for maxIter= and minImprove=
#    : add history.csv in each iteration directory : 2015/11/22
#    : add randomTrial= parameter
# 2.1: use abbsolute path for oFile
#    : available for a int type parameter
# 3.0: add tgp for modeling, add optimum value on estimated surface 2017/06/20
#      modification in visualization, remove log= parameter, etc
#      disavailable for a int type parameter
$version="3.0"
$revision="###VERSION###"

def help

STDERR.puts <<EOF
----------------------------
mbopt.rb version #{$version}
----------------------------
概要) Gaussian Process Regressionを用いた最適化
特徴) 1) Rパッケージtgpを利用している。
用法) mbopt.rb scp= rsl= [mtype=] par= [basemax=] [splitmin=] [arg=]
        [randomTrial=] [maxIter-] [-continue] O= [seed=] [-debug] [--help]

  scp= : 目的関数プログラム名【必須】
       : shellスクリプトでもrubyスクリプトでもCにより作成されたコマンドでも良い。
			 : mbopt.rb内部からコマンドとして起動される。その際のカレントパスは、実行時ディレクトリである。
			 : 引数は以下の通り、mbopt.rbから自動的に設定される。
			 :   1番目: プログラムが返す目的関数の値を保存するJSONファイル名(rsl=で指定した文字列)。
       :   2番目から(1+p)番目: par=で指定したパラメータの値が、その順序で渡される。
			                       :ここで、pはpar=で指定したパラメータ数。全て実数で渡される。
       :   (2+p)番目以降: arg=で指定した値
  rsl= : 目的関数プログラムにより計算された値を格納したJSONファイル名【必須】
	     : 何らかの問題から目的関数が値を計算できない場合はnilを返す。
			 : そうすると、mboptは次にexpected improvementが大きなサンプル点をプログラムに渡して実行を継続する。
			 : 上位5つのサンプル点を与えても値が帰ってこない場合は、ランダムサンプリングによるサンプル点を渡す。
			 : さらにランダムサンプリングを10回繰り返しても値が帰ってこない場合は実行を中止する。
  mtype= : 応答局面のモデル名。gp|tgp(gp:gaussian process regression,tgp:gp with tree)
	       : デフォルトはgp
  par= : パラメータ名と定義域を指定する。【必須】
       : パラメータの名称は結果出力におけるラベルとしてのみ使われるのでどのような名称でもよい。
       : パラメータの指定順序は重要で、scp=で指定したスクリプトの2番目以降の引数として、その順序で渡される。
       : ex. par=support:1:100,confidence:0.5:1.0
			 :    目的関数はsupportとconfidenceという名称の2つのパラメータをとり、
			 :    それらの定義域は1〜100、および0.5〜1.0。
			 :    mbopt.rbは、この定義域においてexpected improvementが最大となるサンプリング点を計算し、
			 :    それらの値をscp=で指定したプログラムに与え実行する。
  basemax= : par=の何番目までをgpモデルの変数として利用するか(最初の変数を1と数える)。
  splitmin= : par=の何番目からをtreeのsplit変数のみに利用するか(最初の変数を1と数える)。
            : basemax=5 splitmin=3の場合、par=の1,2番目の変数はGPのみに用いられ、
						: 3,4,5番目の変数はGPとtreeの分岐の両方に利用され、
						: 6番目から最後の変数まではtreeの分岐にのみ利用される。
						: デフォルトは、basemax=最後の変数,splitmin=1、すなわち全変数をGP,分岐の両方に利用。
  arg= : スクリプトに与えるその他の引数【オプション】
       :   par=で指定した引数の後ろにそのまま付加される。
       :   よって複数の引数を指定する場合はスペースで区切っておく。
  randomTrial= : 最初にパラメータをランダムに決める回数【default:par=で指定した変数の数】
  maxIter= : 最大繰り返し回数【default=20】
  -continue : 既存の結果があれば、その続きから開始する。
	          : その時、maxIter=の値は、以前の実行結果を含む回数である。
  O=   : 出力パス【必須】
  seed=: 乱数の種(0以上の整数)【オプション:指定がなければ時間依存】
  -debug : Rの実行結果を表示
	--help   : ヘルプの表示

出力ファイル)
	O=で指定したパス名の下に"iter_xxx"というディレクトリが生成され、その下に以下の7つのファイルが出力される。
	ただし、randomTrialの時は、GPモデルが構築されないため2,3,5以外は出力されない。
    1) pgr.png     : 応答曲面(gpモデルの回帰超曲面)とexpected improvementの曲面のチャート
    2) history.csv : これまでサンプリングされたパラメータとその目的関数の値、およびexpected improvement。
    3) history.png : 目的関数の値とexpected improvementのこれまでの推移をチャート化したもの。
    4) model.robj  : Rで構築されたGPモデルのシリアライズ。
    5) objVal.json : 目的関数プログラムが返した値のJSON。
    6) optSurf.csv : 応答曲面における、expected improvement最大のサンプル点をスタート点にして、
	                 : 最適化のアルゴリズムで計算された最適値およびそれに対応するパラメータの値
    7) sampling.csv: expected improvementの上位5サンプルのパラメータの値。

必要なソフトウェア)
  1) R
  2) Rのtgpパッケージ(確認の取れているバージョン:2.4.14)

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

args=MCMD::Margs.new(ARGV,"scp=,rsl=,mtype=,opt=,par=,basemax=,splitmin=,arg=,O=,randomTrial=,maxIter=,seed=,-continue,-debug,T=,-mcmdenv,T=","scp=,rsl=,par=,O=")

# mcmdのメッセージは警告とエラーのみ
ENV["KG_VerboseLevel"]="2" unless args.bool("-mcmdenv")

# Rライブラリ実行可能確認
exit(1) unless(MCMD::chkRexe("tgp"))

#ワークファイルパス
if args.str("T=")!=nil then
	ENV["KG_TmpPath"] = args.str("T=").sub(/\/$/,"")
end

scp=args.str("scp=")
objVal=args.str("rsl=")
par=args.str("par=")
arg=args.str("arg=")
oPath=File.expand_path(args.file("O=","w"))
maxIter=args.int("maxIter=",20,1)
randomTrial=args.int("randomTrial=",1,1)
$debug=args.bool("-debug")
cont=args.bool("-continue")
seed=args.int("seed=")
srand(seed) if seed

mtype=args.str("mtype=","gp")
if mtype!="gp" and mtype!="tgp"
	raise "#ERROR# mtype= must be 'gp' or 'tgp'"
end

# x1:-1:5,x2:-1:5
pars={}
pars["name"]=[]
pars["from"]=[]
pars["to"]=[]

psplit=par.split(",")
pars["size"]=psplit.size
psplit.each{|p|
	pEle=p.split(":")
	if pEle.size!=3 then
		raise "#ERROR# each parameter on `par=' have to have four elements delimited by `:'"
	end
	pars["name"] << pEle[0]
	pars["from"] << pEle[1].to_f
	pars["to"]   << pEle[2].to_f
}

randomTrial=pars["size"] if randomTrial < pars["size"]
pars["basemax"]=args.int("basemax=",pars["size"],1,pars["size"])
pars["splitmin"]=args.int("splitmin=",1,1,pars["size"])

def genRand(from,to)
	#rand*(to-from)+from
	rand(from..to)
end

def getRandParms(pars,iter)
	pLists=[]
	(0...iter).each{|iter|
		pList=[]
		(0...pars["size"]).each{|i|
			from=pars["from"][i]
			to  =pars["to"  ][i]
			#pList << rand(from..to).to_s
			pList << genRand(from,to).to_s
		}
		pList << nil # for improvement
		pLists << pList
	}
#puts "getRandParams"
#p pLists
	return pLists
end

def getBestSample(iPath,pars,topK)
	unless File.exist?("#{iPath}/sampling.csv")
		return []
	end

	# sampling.csv
	# x1,x2,x3,improv,rank
	# 1.35059100005712,-1.78755048307456,1.70974605115513,1.38840388867507,4
	# 1.72568620401257,-0.601321200708546,-1.06535568597386,1.37998186626775,2
	wf=MCMD::Mtemp.new
	xxbest=wf.file
	f=""
	f << "mnumber -q a=lineNo i=#{iPath}/sampling.csv |"
	f << "mbest s=rank%n from=0 size=#{topK} o=#{xxbest}"
	system(f)
	
	# arrays for X variables for top K expected improvement
	bestStr=`mcut f=x*,improv -nfno i=#{xxbest}`.strip.gsub("\n",",").split(",")
	bestSamples=[]
	(0...topK).each{|k|
		array=[]
		(0...pars['size']+1).each{|i|
			array << bestStr[i].to_f
		}
		bestSamples << array
	}

	return bestSamples
end

def buildGPmodel(mtype,yVar,xVar,pars,seed,prevIterPath,oPath)
	wf=MCMD::Mtemp.new
	scp=wf.file #"xxscp"
	xFile=wf.file #"xxY"
	yFile=wf.file #"xxX"
	File.open(yFile,"w"){|fpw| yVar.each{|v| fpw.puts(v)}}
	File.open(xFile,"w"){|fpw| xVar.each{|v| fpw.puts(v.join(","))}}

	rFile=wf.file # range for xVar
	File.open(rFile,"w"){|fpw|
		(0...pars["from"].size).each{|i|
			fpw.puts "#{pars["from"][i]},#{pars["to"][i]}"
		}
	}

	nFile=wf.file # names
	File.open(nFile,"w"){|fpw|
		pars["name"].each{|name|
			fpw.puts "#{name}"
		}
	}

	seedText=""
	seedText="set.seed(#{seed})" if seed

	r_scp = <<EOF
library('tgp')

#{seedText}

#### reading field names
fldName=read.csv("#{nFile}",header=F)
fldName=fldName[,1]
print(fldName)

#### reading data files
xvar=read.csv("#{xFile}",header=F) # training xVar
yvar=read.csv("#{yFile}",header=F) # training yVar
xvar=as.matrix(xvar)
yvar=as.vector(yvar)

#### random sampling
rect=read.csv("#{rFile}",header=F) # range for xVar
rect=as.matrix(rect, ncol = 2)
samp=lhs(length(rect)*20, rect)

#### optimum data point in the last iteration
if (file.exists("#{prevIterPath}/optSurf.csv")) {
	prevOpt=read.csv("#{prevIterPath}/optSurf.csv",header=T)
	prevOpt=prevOpt[,colnames(prevOpt)!="y"]
	prevOpt=prevOpt[,colnames(prevOpt)!="iter"]
	samp=rbind(samp,as.matrix(prevOpt,nrow=1))
}

#### GP regression
# generate a GP regression model with calculating top ten sampling points
model=try( b#{mtype}(X=xvar,Z=yvar,XX=samp,improv=c(1,5), basemax=#{pars["basemax"]}, splitmin=#{pars["splitmin"]}),silent=TRUE)
if(class(model)=="try-error"){
	q()
}
png("#{oPath}/tree.png")
	tgp.trees(model)
dev.off()

# write GP regression model
save(model ,file="#{oPath}/model.robj")

# write GP regression plot
xSize=ncol(xvar)
if(xSize==1){
	png("#{oPath}/gpr.png")
		par(mfrow=c(2,1))
		plot(model,layout="surf"          )
		plot(model,layout="as",as="improv")
	dev.off()
} else {
	png("#{oPath}/gpr.png")
		# plt: setting margines
		par(mfrow=c(xSize*(xSize-1)/2,2),plt = c(0.02, 0.98, 0.02, 0.98))
		for (i in 1:(xSize-1)) {
			for (j in (i+1):xSize) {
				plot(model,layout="surf"          ,xlab=fldName[i],ylab=fldName[j], proj=c(i,j))
				plot(model,layout="as",as="improv",xlab=fldName[i],ylab=fldName[j], proj=c(i,j))
			}
		}
	dev.off()
}

#### calculate the optimum xvar and yvar in both xvar and samp
# get optimum for sampling point of xvar and yvar
optYvar=min(c(model$Zp.mean, model$ZZ.mean))
idx=which.min(c(model$Zp.mean, model$ZZ.mean))
both=rbind(xvar, samp)
optXvar=both[idx,]
#optSamp=data.frame(matrix(c(optXvar, optYvar), nrow = 1))
#names(optSamp)=c(paste("x", 1:nrow(rect), sep = ""), "y") 
# output one line csv data like "x1,x2,...,y"
#write.csv(optSamp,"#{oPath}/optSamp.csv",quote=FALSE,row.names=F)

# explore the optimum point on the estimated GP surface starting from optXvar
optSurf=optim.ptgpf(optXvar, rect, model, "L-BFGS-B")
optSurf=data.frame(matrix(c(optSurf$par, optSurf$value), nrow = 1)) # optimum xvar and yvar on the surface
names(optSurf)=c(paste("x", 1:nrow(rect), sep = ""), "y") 
# output one line csv data like "x1,x2,...,y"
write.csv(optSurf,"#{oPath}/optSurf.csv",quote=FALSE,row.names=F)

#### output next 5 sampling points with expected improvement for the next iteration
improv=model$improv
samp=data.frame(samp)
names(samp) <- c(paste("x", 1:nrow(rect), sep=""))
samp=samp[improv[,2] <= 5,] # choose by rank
samp=cbind(samp,improv[improv[,2] <= 5,])
write.csv(samp,"#{oPath}/sampling.csv",quote=FALSE,row.names=F)
EOF

	# write R script, and run it
	exePath=wf.file
	MCMD::mkDir(exePath)
	MCMD::mkDir(oPath)
	File.open(scp,"w"){|fpw| fpw.write r_scp}
	if $debug
		system "cd #{exePath} ; R --vanilla -q < #{scp}"
	else
		system "cd #{exePath} ; R --vanilla -q < #{scp} &>/dev/null"
	end
end

def getLastIterNo(oPath)
	last=-1
	Dir["#{oPath}/iter_*"].each{|it|
		no=it.sub(/^.*iter_/,"").to_i
		last=no if no>last
	}
	return last
end

def readHistory(iFile,pars)
	xVarHis=[]
	yVarHis=[]
	MCMD::Mcsvin.new("i=#{iFile}"){|iCSV|
		iCSV.each{|flds|
			yVal=flds["objValue"].to_f
			yVarHis << yVal
			xVar=[]
			pars['name'].each{|name|
				xVar << flds[name].to_f
			}
			xVarHis << xVar
		}
	}
	return xVarHis,yVarHis
end

def sampling(pars,prevIterPath)
	# sampling X variables with top 5 expected improvement
	xVars1=getBestSample(prevIterPath,pars,5)

	# sampling X variables at random
	xVars2=getRandParms(pars,10)

	return xVars1.concat(xVars2)
end

def execObjectiveFunction(xVars,scp,pars,arg,objVal,thisIterPath)
	yVar=xVar=improv=nil
	(0...xVars.size).each{|k|
		## RUN the Objective Function Here!! ##
		# delete_at(-1) : remove the element of EI
		improv=xVars[k].delete_at(-1)
		system "#{scp} #{objVal} #{xVars[k].join(' ')} #{arg}"

		# copying objVal file as "objVal.json" which is generated in the optimization script
		system "cp #{objVal} #{thisIterPath}/objVal.json"

		# get the objective value returned from the scp
		yVar = File.open(objVal){|fpr| JSON.load(fpr)}

		if yVar
			xVar=xVars[k]
			break
		end
		MCMD::warningLog("   the objective function did not return a value.")
	}
	return yVar,xVar,improv
end

# return the current ranking of yVal
# iter%0n,expImprovement,objective,x1,x2,x3,rank
# 0,,2.497238452,-1.617803189503011,1.7000148047278243,-0.6257063036187969,5
# 1,,2.001004884,-0.9279654404927888,-1.0276931078703342,1.1572219738148268,4
def getInfo(iPath)
	# history.csv
	topSize =`mselstr f=rank v=1 i=#{iPath}/history.csv | mcount a=freq | mcut f=freq -nfno`
	thisRank =`mbest s=iter%nr i=#{iPath}/history.csv | mcut f=rank -nfno`
	thisY=`mbest s=iter%nr i=#{iPath}/history.csv | mcut f=objValue -nfno`
	optY =`mstats f=objValue c=min i=#{iPath}/history.csv | mcut f=objValue -nfno`
	upd=nil
	upd="UPDATED!!" if topSize.to_i==1 and thisRank.to_i==1
	return upd,thisY.to_f,optY.to_f
end

def writeHistory(yVarHis,xVarHis,improvHis,pars,path)
	temp=MCMD::Mtemp.new
	xxtemp=temp.file
	xxscp=temp.file

	# output xVarHis and yVarHis
	MCMD::Mcsvout.new("f=iter,expImprovement,objValue,#{pars['name'].join(',')} o=#{xxtemp}"){|oCSV|
		(0...yVarHis.size).each{|i|
			line=[i,improvHis[i],yVarHis[i]]
			line.concat(xVarHis[i])
			oCSV.write(line)
		}
	}
	system "mnumber s=objValue%n S=1 e=skip a=rank i=#{xxtemp} | msortf f=iter%n o=#{path}/history.csv"

	# history.csv
	# iter%0n,expImprovement,objValue,x1,x2,x3,rank
	# 0,,2.497238452,-1.617803189503011,1.7000148047278243,-0.6257063036187969,4
	# 1,,2.001004884,-0.9279654404927888,-1.0276931078703342,1.1572219738148268,3
	r_scp = <<EOF
d=read.csv("#{path}/history.csv",header=T)
png("#{path}/history.png")
	default.par <- par()
	mai <- par()$mai
	mai[4] <- mai[1]
	par(mai = mai)
	options(warn=-1)
	matplot(d$iter,d$objValue,col="royalblue3",pch=c(15,0),cex=1,type="b",lwd=2,lty=1,ylab="objective value",xlab="iteration")
	par(new=T)
	ret=try(matplot(d$iter,d$expImprovement,col="brown3",pch=c(15,0),cex=1,type="b",lwd=2,lty=1,axes=F,ylab="",xlab=""),silent=TRUE)
	axis(4)
	mtext("expected improvement", side = 4, line = 3)
	par(default.par)
	legend("top", legend=c("OF", "EI"), col=c("royalblue3","brown3"),pch=c(15,0), lwd=2, lty=1)
	title("development of EI and OF")
	options(warn=0)
dev.off()
EOF
	File.open(xxscp,"w"){|fpw| fpw.write r_scp}
	if $debug
		system "R --vanilla -q < #{xxscp}"
	else
		system "R --vanilla -q < #{xxscp} &>/dev/null"
	end
end

############################## main
MCMD::mkDir(oPath)

# set a starting iteration number
startIter=0
xVarHis=[]
yVarHis=[]
improvHis=[]

# in continue mode
startIter=getLastIterNo(oPath)+1 if cont

# 1. adaptive sampling => xVarCands
# 2. execute an objective function => yVar,xVar => new data
# 3. build a GP regression model
# 4. update the optimum(minimum) yVal for sampling point xVar and estimated surface
(startIter...maxIter).each{|iter|
	MCMD.msgLog("##### iteration ##{iter} starts.")

	prevIterPath="#{oPath}/iter_#{sprintf('%04d',iter-1)}"
	thisIterPath="#{oPath}/iter_#{sprintf('%04d',iter)}"
	MCMD::mkDir(thisIterPath)

	# sampling candiate points of X variables and their EI
	xVarCands=sampling(pars,prevIterPath)

	# execute objective function using X variables on xVarCands one by one
	# and get yVar and xVar.
	yVar,xVar,improv=execObjectiveFunction(xVarCands,scp,pars,arg,objVal,thisIterPath)

	unless yVar
		MCMD::warningLog("   finally give up to get a value")
		break
	end

	# add xVar and yVar to 
	xVarHis << xVar
	yVarHis << yVar
	improvHis << improv

	# update GP regression model using xVar and yVar as a training data,
	# and copy all necessary files to thisIterPath.
	# no model is built if iter<randomTrial, meaning to use random sampling point.
	if iter>=randomTrial-1
		buildGPmodel(mtype,yVarHis,xVarHis,pars,seed,prevIterPath,thisIterPath)
		MCMD::warningLog("   GP model was not built") unless File.exist?("#{thisIterPath}/model.robj")
	else
		MCMD::msgLog("   skip modeling in random trial")
	end

	# write all values of yVar, xVar and EI, which are previously examined.
	writeHistory(yVarHis,xVarHis,improvHis,pars,thisIterPath)

	# ranking of yVar for this iteration
	upd,thisY,optY=getInfo(thisIterPath)

	MCMD::msgLog("   BEST OBJ VALUE: #{optY} (this trial:#{thisY}) #{upd}")
}

# end message
MCMD::endLog(args.cmdline)

