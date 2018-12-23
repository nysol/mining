#!/usr/bin/env ruby
# encoding: utf-8

# 1.1 fix the but about dimention mismatch: 2014/09/03
# 1.2 add -nocv mode, use JSON: 2015/01/11
# 1.3 add -z option, add original strings for xvar in coeff.csv : 2015/03/02
# 1.4 bug fix about NaN problem in specifing -z option : 2015/03/02
# 1.5 bug fix for key mismatching problem between x and y files : 2015/03/03
# 1.6 bug fix for prediction in logistic regression : 2015/03/27
# 2.0 run on the latest version of glmnet (2.0-16) : 2018/11/29
$version="2.0"
$revision="###VERSION###"

def help

STDERR.puts <<EOF
----------------------------
m2glmnet.rb version #{$version}
----------------------------
概要) Rのglmnetパッケージを利用した正則化法による回帰モデルの構築
特徴) 1) リッジ回帰、LASSO、elastic-netの正則化を指定可能
      2) 入力データは、サンプルID,featureID,値の3項目CSVデータ
      3) 交差検証(CV)によりlambdaを決定することで最適モデルを構築可
      4) 線形回帰、ロジスティック回帰、ポアッソン回帰など指定可能
      5) Rスクリプトを書く必要はない
用法1) autoモード
  a) sparse matrixによる入力ファイル指定の場合
    m2glmnet.rb -sparse family=[gaussian|binomial|poisson] [alpha=] i= k= x= [v=] c= y= exposure= O= [-z] [seed=] [T=] [-mcmdenv] [--help]

      -sparse : このオプションが指定されて初めてスパースマトリックスモードとみなされる【必須】
      i=      : スパースマトリックス型入力データファイル名【必須】
      k=      : サンプルid項目名【必須】
      x=      : 説明変数を表す項目名【必須】
      v=      : 説明変数の値項目名【オプション】
              : 指定しなければ、全行1(すなわちダミー変数)となる。
      c=      : 目的変数データファイル名【選択必須】
      y=      : 目的変数の項目名【必須】
              : family=で指定した内容により以下に示す値である必要がある。
              :   gaussian: 実数
              :   poisson: 正の整数
              :   binomial: 2つのクラス値(文字列でも可)

  b) matrixによる入力ファイル指定の場合

    m2glmnet.rb family=[gaussian|binomial|poisson] [alpha=] i= x= y= exposure= O= [-z] [seed=] [T=] [-mcmdenv] [--help]
      i=      : マトリックス型入力データファイル名【必須】
      x=      : 説明変数項目名リスト【必須】
      y=      : 目的変数項目名【選択必須】
      O=      : 出力ディレクトリ名【必須】

  ## モデル構築関連パラメータ(a,b共通)
  family=  : リンク関数【必須】
           : gaussian: 線形回帰
           : poisson: ポアソン回帰
           : binomial: ロジスティック回帰
  alpha=   : elastic-netにおけるL1とL2正則化項の荷重【デフォルト:1.0】
           : 1.0でL1正則化、0でL2正則化(リッジ回帰)、0<alpha<1でelastic-net
  seed=    : 乱数の種(0以上の整数,交差検証に影響)【オプション:default=-1(時間依存)】
  -z       : 内部で説明変数を標準化する。
           :   スケールの異なる変数の係数を比較したい場合に利用する。
           :   -zをつけて作成されたモデルで予測することには意味がないことに注意する。
  lambda=  : 正則化項の重み

  ## その他のパラメータ
  T=       : 作業ディレクトリ【デフォルト:"/tmp"】
  -verbose : 実行内容を画面に出力する
  -mcmdenv : 内部のMCMDのコマンドメッセージを表示
  --help   : ヘルプの表示

 
用法2) マニュアルモード(autoモードは、以下のa)〜f)のステップを連続して実行している)
  a) データのシリアライズ(sparse matrix): 
    m2glmnet.rb mode=data -sparse  i= k= x= [v=] c= y= exposure= O= [-z] [T=] [-mcmdenv] [--help]
  b) データのシリアライズ(matrix): 
    m2glmnet.rb mode=data i= x= y= exposure= O=出力パス [-z] [T=] [-mcmdenv] [--help]
  c) CVによるlambda別モデル評価
    m2glmnet.rb mode=cv family=[gaussian|binomial|poisson] [alpha=] D=シリアライズデータパス O=出力パス
  d) lambdaを指定してモデル構築
    m2glmnet.rb mode=model  family=[gaussian|binomial|poisson] [alpha=] D=シリアライズデータパス lambda= O=出力パス
  e) 予測(sparse matrix)
    m2glmnet.rb mode=predict i= [c=] [exposure=] M=モデルパス O=出力パス
  f) 予測(matrix)
    m2glmnet.rb mode=predict i= M=モデルパス O=出力パス

必要なソフトウェア)
  1) R
  2) Rのglmnetパッケージ, ROCRパッケージ

例)
  説明変数(sparse matrix): man1x.csv
  tid,item,val
  t1,a,1
  t1,c,2
  t1,d,1
  t1,e,3
  t2,a,1
  t2,e,1
  t3,b,1
  t3,d,1
  t3,e,2
  t4,a,1
  t4,c,4

  目的変数: man1y.csv
  tid,profit
  t1,10
  t2,0
  t3,-23
  t4,20

  $ m2glmnet.rb family=gaussian i=man1x.csv k=tid x=item v=val c=man1y.csv y=profit O=result -sparse                                               

  出力結果
  result/data
          /key2sno.csv        : i=のk=項目とR内部の行番号の対応表
          /params_data.json   : 実行パラメータ
          /serializeDataSMX.R : シリアライズで実行されたRスクリプト
          /var2vno.csv        : i=のx=項目とR内部のfeature番号の対応表
          /xMTX.robj          : シリアライズされた説明変数
          /yMTX.robj          : シリアライズされた目的変数
        /cv
          /coef.csv       : lambda別係数一覧
          /coef.png       : lambda別係数チャート
          /cv.R           : CVで実行されたRスクリプト
          /dev_ratio.csv  : 
          /info.csv       : 回帰モデルに関する各種情報
          /lambda.csv     : lambda別の各種情報(deviance,係数が非0のfeature数、推定誤差など)
          /lmbda.png      : lambda別エラーチャート
          /model.robj     : 回帰モデルのRオブジェクト
          /params_cv.json : 実行パラメータ
        /model
          /lambda_14.2894191624432
            /buildModel.R      : モデル構築で実行されたRスクリプト
            /coef.csv          : 回帰係数
            /info.csv          : 回帰モデルに関する各種情報
            /model.robj        : 回帰モデルのRオブジェクト
            /params_model.json : 実行パラメータ
            /predict.csv       : モデルによる予測結果

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
require "json"
#DebugPath="./xxtmp"
DebugPath=nil

# Rライブラリ実行可能確認
exit(1) unless(MCMD::chkRexe("glmnet"))
exit(1) unless(MCMD::chkRexe("ROCR"))

# traデータからsparseMatrix用データを作成する
# 1) var2vnoがnullならば、ifileからvar2vnoを生成。指定されていれば、そのファイルを使って変換
# 2) key2sno変換表を出力(key2sno)
# 3) key,varがnumに変換されたデータを出力(row,col,val)
def smatrix(ifile,key,var,val,cFile,predictMode,var2vno,key2sno,xxrow,xxcol,xxval,existingVar2vno)
	MCMD::msgLog("#{File.basename($0)}: cleaning a sparse matrix data `#{ifile}' ...")

	wf=MCMD::Mtemp.new(DebugPath)
	xxbase =wf.file
	xxa    =wf.file

	#  1) add value "1" unless v= not specified.
	#  2) make unique by key and var
	f=""
	if val
		f << "mcut   f=#{key}:key,#{var}:var,#{val}:val i=#{ifile} |"
	else
		f << "mcut   f=#{key}:key,#{var}:var i=#{ifile} |"
		f << "msetstr v=1 a=val |"
	end

	if cFile
		f << "mcommon k=key K=#{key} m=#{cFile} |"
	end

	f << "msortf f=key,var |"
	f << "muniq  k=key,var o=#{xxbase}"
	system(f)

	recSize=MCMD::mrecount("i=#{xxbase}")
	if recSize==0
		raise "#ERROR# common records between x and y files are not found"
	end

	if existingVar2vno then
		system("cp #{existingVar2vno} #{var2vno}")
	else
		MCMD::msgLog("#{File.basename($0)}: creating a mapping table of variables and their number...")
		f=""
		f << "mcut    f=var i=#{xxbase} |"
		f << "muniq   k=var |"
		f << "mnumber s=var a=vno S=1 o=#{var2vno}"
		system(f)
	end

	MCMD::msgLog("#{File.basename($0)}: creating a mapping table of key and its number...")
	f=""
	f << "mcut    f=key i=#{xxbase} |"
	f << "muniq   k=key |"
	f << "mnumber s=key a=sno_ S=1 o=#{key2sno}"
	system(f)

	MCMD::msgLog("#{File.basename($0)}: creating index list and value list for initializing a sparse matrix...")
	f=""
	f << "mcut   f=key,var,val i=#{xxbase} |"
	f << "mjoin  k=key m=#{key2sno} f=sno_ |"
	f << "msortf f=var |"
	f << "mjoin  k=var m=#{var2vno} f=vno o=#{xxa}"
	system(f)

	system "mcut f=sno_ i=#{xxa} o=#{xxrow}"
	system "mcut f=vno     i=#{xxa} o=#{xxcol}"
	system "mcut f=val     i=#{xxa} o=#{xxval}"

	rowSize=MCMD::mrecount("i=#{key2sno}")
	colSize=MCMD::mrecount("i=#{var2vno}")

	return rowSize,colSize
end

def mkYvar(cfile,key,yVar,xxkey2sno,xxy)
	if xxy
		f=""
		f << "mcut f=#{key}:key,#{yVar} i=#{cfile} |"
		f << "mjoin   k=key m=#{xxkey2sno} f=sno_ |"
		f << "mcut    f=sno_,#{yVar} |"
		f << "msortf  f=sno_%n o=#{xxy}"
		system(f)
	end
end

def mkExposure(cfile,key,exposure,xxkey2sno,xxexposure)
	if xxexposure
		f=""
		f << "mcut f=#{key}:key,#{exposure}:exposure i=#{cfile} |"
		f << "mjoin   k=key m=#{xxkey2sno} f=sno_ |"
		f << "mcut    f=sno_,exposure |"
		f << "msortf  f=sno_%n |"
		f << "mcut    f=exposure o=#{xxexposure}"
		system(f)
	end
end


#################################################################################################
#### generate R scripts

#######################
## pre-process
def scpHeader(seed=nil)
	scp=""
	scp << "library(glmnet)\n"
	scp << "set.seed(#{seed})\n" if seed
	return scp
end

#######################
## prediction script using an existing model (sparse matrix version)
##   modelFile: model file (model.robj)
##   lambda:  lambda value. It make prediction using the model with the given lambda value
##   exposureFile: exposure file (nil unless poisson regression)
##   oFile: output file name
def scpLoadModel(modelFile)
	scp = <<EOF
#####################################
## loading the model
load(\"#{modelFile}\")
EOF
	return scp
end

def scpPredict(key,oPath)
	scp = <<EOF
#####################################
## prediction
if (exists(\"exposureMTX\")) {
	prd = predict(model,xMTX,model$lambda,newoffset=log(exposureMTX))
}else{
	prd = predict(model,xMTX,model$lambda)
}

if (model$call$family=="binomial") {
	prd = 1/(1+exp((-1)* prd))
} else if (model$call$family=="poisson") {
	prd = exp(prd)
}

if (exists("yMTX")) {
	actprd=data.frame(row.names(prd),yMTX,prd)
	colnames(actprd)=c("#{key}",colnames(yMTX),"predict")
}else{
	actprd=data.frame(row.names(prd),prd)
	colnames(actprd)=c("#{key}","predict")
}

prdFile=paste("#{oPath}","/predict.csv",sep="")
write.csv(actprd,file=prdFile,row.names=FALSE,quote=FALSE)
EOF
	return scp
end

def scpInpSMX(rowSize,colSize,rowFile,colFile,valFile,var2vnoFile,key2snoFile,exposureFile,doZ,yFile)
	scp=""
	scp << "library(glmnet)\n"
	scp << "#####################################\n"
	scp << "## loading csv data and setting sparseMatrix\n"
	scp << "row = read.csv(\"#{rowFile}\")$sno_\n"
	scp << "col = read.csv(\"#{colFile}\")$vno\n"
	scp << "val = read.csv(\"#{valFile}\")$val\n"
	scp << "cname = read.csv(\"#{var2vnoFile}\")[,1]\n"
	scp << "rname = read.csv(\"#{key2snoFile}\")[,1]\n"
	scp << "xMTX=sparseMatrix(i=row,j=col,x=val,dims=c(#{rowSize},#{colSize}))\n"

	if doZ then
		scp << "#####################################\n"
		scp << "## standardizing x variables\n"
		scp << "xMTX=apply(xMTX,2,scale)\n"
		scp << "xMTX[is.na(xMTX)] <- 0\n"
	end

	scp << "colnames(xMTX)=cname\n"
	scp << "rownames(xMTX)=rname\n"

	if yFile then
		scp << "#####################################\n"
		scp << "## setting csv data into a vector of objective valiable\n"
		scp << "yMTX= as.matrix(read.csv(\"#{yFile}\",header=T)[2])\n"
		scp << "rownames(yMTX)=rname\n"
	end

	if exposureFile
		scp << "exposureMTX= as.matrix(read.csv(\"#{exposureFile}\"))\n"
		scp << "rownames(exposureMTX)=rname\n"
	end

	return scp
end

def scpInpMTX(ifile,key,var,exposure,yVar,doZ,xxdata)
	flds="#{key},#{var}"
	flds << ",#{yVar}"     if yVar
	flds << ",#{exposure}" if exposure
	f=""
	f << "mcut f=#{flds} i=#{ifile} o=#{xxdata}"
	system(f)

	scp = ""
	scp << "#####################################\n"
	scp << "## loading csv data setting matrix\n"
	scp << "data= read.csv(\"#{xxdata}\")\n"
	scp << "xMTX=data[c(\"#{var.gsub(",",'","')}\")]\n"
	scp << "rownames(xMTX)=data$#{key}\n"
	scp << "xMTX=as.matrix(xMTX)\n"

	if doZ
		scp << "#####################################\n"
		scp << "## standardizing x variables\n"
		scp << "xMTX=apply(xMTX,2,scale)\n"
	end

	if yVar
		scp << "yMTX=data[c(\"#{yVar}\")]\n"
		scp << "rownames(yMTX)=data$#{key}\n"
		scp << "yMTX=as.matrix(yMTX)\n"
	end

	if exposure
		scp << "exposureMTX=data[c(\"#{exposure}\")]\n"
		scp << "rownames(exposureMTX)=data$#{key}\n"
		scp << "exposureMTX=as.matrix(exposureMTX)\n"
	end

	return scp
end

def scpSaveData(oPath)
	scp = <<EOF
#####################################
## output the serialized data
xMTXFile=paste("#{oPath}","/xMTX.robj",sep="")
save(xMTX ,file=xMTXFile)
if (exists("yMTX")) {
	yMTXFile=paste("#{oPath}","/yMTX.robj",sep="")
	save(yMTX ,file=yMTXFile)
}
if (exists("exposureMTX")) {
	exposureMTXFile=paste("#{oPath}","/exposureMTX.robj",sep="")
	save(exposureMTX ,file=exposureMTXFile)
}
EOF
	return scp
end

def scpLoadData(dataPath)
	scp = <<EOF
#####################################
## loading the serialized dataset
xMTXFile=paste("#{dataPath}","/xMTX.robj",sep="")
load(xMTXFile)
yMTXFile=paste("#{dataPath}","/yMTX.robj",sep="")
if (file.exists(yMTXFile)) {
	load(yMTXFile)
}
exposureMTXFile=paste("#{dataPath}","/exposureMTX.robj",sep="")
if (file.exists(exposureMTXFile)) {
	load(exposureMTXFile)
}
EOF
	return scp
end

def scpCV(family,alpha)
	scp = <<EOF
	if (exists("exposureMTX")) {
		cv = cv.glmnet(xMTX,yMTX,family=\"#{family}\",alpha=#{alpha},offset=log(exposureMTX))
	} else {
		cv = cv.glmnet(xMTX,yMTX,family=\"#{family}\",alpha=#{alpha})
	}
EOF
	return scp
end

def scpModel(family,alpha,lambda)
	scp = <<EOF
	if(exists("exposureMTX")) {
		model = glmnet(xMTX,yMTX,family=\"#{family}\",alpha=#{alpha},offset=log(exposureMTX),lambda=#{lambda})
	}else{
		model = glmnet(xMTX,yMTX,family=\"#{family}\",alpha=#{alpha},lambda=#{lambda})
	}
EOF
	return scp
end

def scpROC(oPath)
	scp = <<EOF
	library(ROCR)
	actprd=read.csv("#{oPath}/predict.csv")
	roc_pred=prediction(actprd[,3], actprd[,2])
	roc=performance(roc_pred, "tpr", "fpr")
	rocFile=paste("#{oPath}","/roc.png",sep="")
	png(rocFile)
		plot(roc)
	supmsg=dev.off()
	table = data.frame(cutoff=unlist(roc_pred@cutoffs),
	  TP=unlist(roc_pred@tp), FP=unlist(roc_pred@fp),
	  FN=unlist(roc_pred@fn), TN=unlist(roc_pred@tn),
	  sensitivity=unlist(roc_pred@tp)/(unlist(roc_pred@tp)+unlist(roc_pred@fn)),
	  specificity=unlist(roc_pred@tn)/(unlist(roc_pred@fp)+unlist(roc_pred@tn)),
	  accuracy=((unlist(roc_pred@tp)+unlist(roc_pred@tn))/nrow(actprd))
	)
	rocTable=paste("#{oPath}","/roc.csv",sep="")
	write.csv(table,file=rocTable,row.names=FALSE,quote=FALSE)

	auc0=performance(roc_pred,"auc")
	auc =as.numeric(auc0@y.values)
	#prbe0=performance(roc_pred,"prbe")
	#prbe =as.numeric(prbe0@x.values)
	rocEvaluation=paste("#{oPath}","/roc_info.csv",sep="")
	write.csv(data.frame(auc),file=rocEvaluation,row.names=FALSE,quote=FALSE)
EOF

	return scp
end

def scpCVresult(oPath)
	r_post_proc = <<EOF
#####################################
## output the serialized objects of the model
modelFile=paste("#{oPath}","/model.robj",sep="")
save(cv ,file=modelFile)

#####################################
## output coefficients on each lambda
coefFile=paste("#{oPath}","/coef.csv",sep="")
a1=as.data.frame(as.matrix(coef(cv$glmnet.fit)))
a0=data.frame(rownames(a1))
colnames(a0)="variable"
write.csv(data.frame(a0,a1),file=coefFile,row.names=FALSE,quote=FALSE)

coefPNG=paste("#{oPath}","/coef.png",sep="")
png(coefPNG)
 	plot(cv$glmnet.fit,"lambda")
supmsg=dev.off()

#####################################
## setting the model info
info=as.data.frame(cv$glmnet.fit$nobs)
colnames(info)=c("nobs")
info$colsize=cv$glmnet.fit$dim[2]
info$nulldev=cv$glmnet.fit$nulldev

#####################################
## output results of cv in csv format
fitFile=paste("#{oPath}","/dev_ratio.csv",sep="")
fit=as.data.frame(c(0:(length(cv$glmnet.fit$lambda)-1)))
colnames(fit)=c("sno")
fit$lambda=cv$glmnet.fit$lambda
fit$df=cv$glmnet.fit$df
fit$dev.ratio=cv$glmnet.fit$dev.ratio
write.csv(fit,fitFile,row.names=FALSE,quote=FALSE)

lambdaFile=paste("#{oPath}","/lambda.csv",sep="")
stats=as.data.frame(c(0:(length(cv$lambda)-1)))
colnames(stats)=c("sno")
stats$lambda=cv$lambda
stats$cvm=cv$cvm
stats$cvsd=cv$cvsd
stats$cvup=cv$cvup
stats$cvlo=cv$cvlo
stats$nzero=cv$nzero
write.csv(stats,lambdaFile,row.names=FALSE,quote=FALSE)

infoFile=paste("#{oPath}","/info.csv",sep="")
info$lambda_min=cv$lambda.min
info$lambda_1se=cv$lambda.1se
write.csv(info,infoFile,row.names=F,quote=FALSE)

lambdaPNG=paste("#{oPath}","/lambda.png",sep="")
png(lambdaPNG)
 	plot(cv)
supmsg=dev.off()
EOF

	return r_post_proc
end

def scpModelResult(oPath)
	r_post_proc = <<EOF
#####################################
## output serialized objects of the model
modelFile=paste("#{oPath}","/model.robj",sep="")
save(model ,file=modelFile)

#####################################
## output coefficients on each lambda
coefFile=paste("#{oPath}","/coef.csv",sep="")
a1=as.data.frame(as.matrix(coef(model)))
a0=data.frame(rownames(a1))
colnames(a0)="variable"
write.csv(data.frame(a0,a1),file=coefFile,row.names=FALSE,quote=FALSE)

#####################################
## setting the model info
info=as.data.frame(model$nobs)
colnames(info)=c("nobs")
info$colsize=model$dim[2]
info$lambda=model$lambda
info$nulldev=model$nulldev
info$devRatio=model$dev.ratio
info$df=model$df
info$classnames=paste(model$classnames,collapse=" ")

infoFile=paste("#{oPath}","/info.csv",sep="")
write.csv(info,infoFile,row.names=F,quote=FALSE)
EOF
end

#######################
def setEnv(args)
	# mcmdのメッセージは警告とエラーのみ
	ENV["KG_VerboseLevel"]="2" unless args.bool("-verbose")
	ENV["KG_ScpVerboseLevel"]="3" unless args.bool("-verbose")

	#ワークファイルパス
	if args.str("T=")!=nil then
		ENV["KG_TmpPath"] = args.str("T=").sub(/\/$/,"")
	end
end

def runRSCP(scps,oPath,name,verbose=False)
	# writing the R script
	script=scps.join("\n")
	File.open("#{oPath}/#{name}.R","w"){|fpw|
		fpw.puts "#{script}"
	}
	MCMD::msgLog("#{File.basename($0)}: executing the R script: #{oPath}/#{name}.R ...")
  if verbose then
		ret=system "R --vanilla -q < #{oPath}/#{name}.R 2>&1"
		raise "#ERROR# error happened in executing the R script(#{oPath}/#{name}.R)." if not ret
  else
    ret=system "R --vanilla -q < #{oPath}/#{name}.R > #{oPath}/#{name}.rlog 2>&1"
		raise "#ERROR# error happened in executing the R script(#{oPath}/#{name}.R). refer the executing log:#{oPath}/#{name}.rlog." if not ret
  end
end

# saving the parameters
def saveParams(args,oPath,name)
	File.open("#{oPath}/params_#{name}.json","w"){|fpw|
		JSON.dump(args.getKeyValue,fpw)
	}
end

def loadParams(iPath,name)
	params=nil
	File.open("#{iPath}/params_#{name}.json","r"){|fpr|
		params=JSON.load(fpr)
	}
	dict={}
	params.each{|param|
		if param[0][0]=="-"
			if param[1]=="true"
				dict[param[0]]=true
			else
				dict[param[0]]=false
			end
		else
			dict[param[0]]=param[1]
		end
	}
	return dict
end

# read sparse matrix data in csv format and save it as a R serialized object
def serializeDataSMX(ifile,cfile,oPath,doZ,key,var,val,yVar,exposure,verbose,existingVar2vno)
	wf=MCMD::Mtemp.new(DebugPath)
	xxrow     =wf.file
	xxcol     =wf.file
	xxval     =wf.file
	xxy       =wf.file if cfile
	xxexposure=wf.file if exposure

	# preprocessing for x and y variables
	rowSize,colSize=smatrix(ifile,key,var,val,cfile,false,"#{oPath}/var2vno.csv","#{oPath}/key2sno.csv",xxrow,xxcol,xxval,existingVar2vno)
	mkYvar(cfile,key,yVar,"#{oPath}/key2sno.csv",xxy)
	mkExposure(cfile,key,exposure,"#{oPath}/key2sno.csv",xxexposure)

	# csv data => R data.frame
	scp1=scpInpSMX(rowSize,colSize,xxrow,xxcol,xxval,"#{oPath}/var2vno.csv","#{oPath}/key2sno.csv",xxexposure,doZ,xxy)
	scp2=scpSaveData(oPath)

	runRSCP([scp1,scp2],oPath,"serializeDataSMX",verbose)
end

def serializeDataMTX(ifile,oPath,doZ,key,var,yVar,exposure,verbose)
	wf=MCMD::Mtemp.new(DebugPath)
	xxdata =wf.file

	scp1=scpInpMTX(ifile,key,var,exposure,yVar,doZ,xxdata)
	scp2=scpSaveData(oPath)

	runRSCP([scp1,scp2],oPath,"serializeDataMTX",verbose)
end

def buildModel(dataPath,modelPath,family,alpha,lambda,seed,param,key,verbose)
	# model building for lambda_1se
	scp0=scpHeader(seed)
	scp1=scpLoadData(dataPath)
	scp2=scpModel(family,alpha,lambda)
	scp3=scpModelResult(modelPath)
	scp4=scpPredict(key,modelPath)
	scp5=scpROC(modelPath) if family=="binomial"
	runRSCP([scp0,scp1,scp2,scp3,scp4,scp5],modelPath,"buildModel",verbose)
end

# cross varidation
def cv(dataPath,cvPath,family,alpha,seed,param,verbose)
	scp0=scpHeader(seed)
	scp1=scpLoadData(dataPath)
	scp2=scpCV(family,alpha)
	scp3=scpCVresult(cvPath)
	runRSCP([scp0,scp1,scp2,scp3],cvPath,"cv",verbose)
end

def predict(dataPath,modelPath,oPath,key,verbose)
	scp0=scpHeader()
	scp1=scpLoadData(dataPath)
	scp2=scpLoadModel("#{modelPath}/model.robj")
	scp3=scpPredict(key,oPath)
	runRSCP([scp0,scp1,scp2,scp3],oPath,"predict",verbose)
end

def getLambdaMin1SE(cvPath)
	# #{cvPath}/info.csv
	# nobs,colsize,nulldev,lambda_min,lambda_1se
	# 20,75,26.9204666803703,0.00033428383408493,0.000366876095200709
	tbl=MCMD::Mtable.new("i=#{cvPath}/info.csv")
	lambda_min=tbl.cell(3,0)
	lambda_1se=tbl.cell(4,0)
	return [lambda_min,lambda_1se]
end


########################
## dataset mode
def runData(argv)
	args=MCMD::Margs.new(argv,"mode=,i=,c=,O=,k=,x=,v=,y=,exposure=,T=,-verbose,-z,-sparse","k=,x=,y=,i=,O=")
	setEnv(args)

	isSMX=args.bool("-sparse") # flag for sparse matrix or matrix

	# convert tra file to sparse matrix
	if isSMX then
		ifile =args.file("i=","r")
		cfile =args.file("c=","r")
		oPath =args.str("O=")
		MCMD::mkDir(oPath)

		doZ=args.bool("-z") # standardization
		key  = args.field("k=" , ifile, nil , 1,1)["names"].join(",")
		var = args.field("x=", ifile, nil, 1,1)["names"][0]
		val = args.field("v=", ifile, nil, 1,1)
		val = val["names"][0] if val
		yVar = args.field("y=", cfile, nil, 1,1)["names"][0]
		exposure= args.field("exposure=",cfile,nil,1,1)
		exposure=exposure["names"][0] if exposure
		verbose=args.bool("-verbose")

		serializeDataSMX(ifile,cfile,oPath,doZ,key,var,val,yVar,exposure,verbose,nil)
	else
		ifile =args.file("i=","r")
		oPath =args.str("O=")
		MCMD::mkDir(oPath)
    key  = args.field("k=", ifile, nil, 1)["names"].join(",")
	  var  = args.field("x=", ifile, nil, 1)["names"].join(",")
		yVar = args.field("y=", ifile, nil, 1,1)["names"][0]
		exposure= args.field("exposure=",ifile,nil,1,1)
		exposure=exposure["names"][0] if exposure
		verbose=args.bool("-verbose")

		serializeDataMTX(ifile,oPath,doZ,key,var,yVar,exposure,verbose)
	end
	saveParams(args,oPath,"data")
end

########################
#### cv mode
def runCV(argv)
	args=MCMD::Margs.new(argv,"mode=,D=,O=,alpha=,family=,T=,-verbose,-z,T=,param=,seed=","D=,O=")
	setEnv(args)

	alpha   = args.float("alpha=", 1.0, 0.0, 1.0)
	family  = args.str("family=")
	seed    = args.int("seed=", -1)
	param   = args.str("param=")
	param   = ","+param if param
	verbose = args.bool("-verbose")

	dataPath=args.file("D=", "r")
	oPath   =args.str("O=")
	MCMD::mkDir(oPath)
	if not (File.exists?("#{dataPath}/xMTX.robj") and File.exists?("#{dataPath}/yMTX.robj"))
		raise "#ERROR# cannot find the serialied data set in #{dataPath}. Serialize the csv data run by mode=data."
	end

	cv(dataPath,oPath,family,alpha,seed,param,verbose)
	saveParams(args,oPath,"cv")
end

########################
#### model building mode
def runModel(argv)
	args=MCMD::Margs.new(argv,"mode=,D=,O=,alpha=,family=,lambda=,T=,-verbose,-z,T=,param=,seed=","D=,O=,lambda=")
	setEnv(args)

	alpha   = args.float("alpha=", 1.0, 0.0, 1.0)
	lambda  = args.float("lambda=")
	family  = args.str("family=", "gaussian")
	seed    = args.int("seed=", -1)
	param   = args.str("param=")
	param   = ","+param if param
	verbose=args.bool("-verbose")

	dataPath=args.file("D=", "r")
	dataParams=loadParams(dataPath,"data")
	key       =dataParams["k="]

	oPath   =args.str("O=")
	MCMD::mkDir(oPath)
	if not (File.exists?("#{dataPath}/xMTX.robj") and File.exists?("#{dataPath}/yMTX.robj"))
		raise "#ERROR# cannot find the serialied data set in #{dataPath}. Serialize the csv data run by mode=data."
	end

	buildModel(dataPath,oPath,family,alpha,lambda,seed,param,key,verbose)
	saveParams(args,oPath,"model")
end

########################
## predict mode
def runPredict(argv)
	args=MCMD::Margs.new(argv,"mode=,i=,M=,O=,c=,T=,-verbose,T=","i=,M=,O=")
	setEnv(args)

	oPath =args.str("O=")
	MCMD::mkDir(oPath)

	# [["mode=","model"],["family=","binomial"],["lambda=","0.001"],["D=","xxoutSMTX/data"],["O=","xxoutSMTX/model/lambda_0.001"],["-verbose","true"],["-z","false"]]
	modelPath = args.file("M=","r")
	modelParams=loadParams(modelPath,"model")
	family  =modelParams["family="]
	lambda  =modelParams["lambda="].to_f
	dataPath=modelParams["D="]

	# [["mode=","data"],["k=","id"],["x=","x"],["v=","v"],["i=","../../../dataset/data/baloon01_x.csv"],["y=","inflated"],["c=","../../../dataset/data/baloon01_y.csv"],["O=","xxoutSMTX"],["-sparse","true"],["-verbose","true"],["-z","false"]]
	dataParams=loadParams(dataPath,"data")
	isSMX   =dataParams["-sparse"]

	if isSMX then
		ifile =args.file("i=","r")
		cfile =args.file("c=","r")

		key     =dataParams["k="]
		var     =dataParams["x="]
		val     =dataParams["v="]
		yVar    =dataParams["y="]
		doZ     =dataParams["-z"]
		exposure=dataParams["exposure="]
		verbose=args.bool("-verbose")

		serializeDataSMX(ifile,cfile,oPath,doZ,key,var,val,yVar,exposure,verbose,"#{dataPath}/var2vno.csv")
	else
		ifile =args.file("i=","r")

		key     =dataParams["k="]
		var     =dataParams["x="]
		yVar    =dataParams["y="]
		doZ     =dataParams["-z"]
		exposure=dataParams["exposure="]
		verbose=args.bool("-verbose")

		serializeDataMTX(ifile,oPath,doZ,key,var,yVar,exposure,verbose)
	end
	
	dataPath=oPath
	predict(dataPath,modelPath,oPath,key,verbose)
	saveParams(args,oPath,"predict")
end

#################################################################################################
#### Entry point

########################
## dataset mode
if ARGV.index("mode=data")
	runData(ARGV)
elsif ARGV.index("mode=cv")
	runCV(ARGV)
elsif ARGV.index("mode=model")
	runModel(ARGV)
elsif ARGV.index("mode=predict")
	runPredict(ARGV)
else
	args=MCMD::Margs.new(ARGV,"mode=,O=,i=,c=,k=,x=,v=,y=,exposure=,alpha=,family=,T=,-verbose,-z,T=,param=,seed=,-sparse","k=,x=,y=,i=,O=,family=")
	orgArgs={}
	args.getKeyValue.each{|k,v| orgArgs[k]=v}
	oPath=orgArgs["O="]

	# data serialization
	dataArgs=[]
	dataArgs << "O=#{oPath}/data"
	["i=","c=","k=","x=","v=","y=","exposure=","T=","-verbose","-z","-sparse"].each{|key|
		if orgArgs[key]
			if key[0]=="-"
				dataArgs << key if orgArgs[key]=="true"
			else
				dataArgs << "#{key}#{orgArgs[key]}"
			end
		end
	}
	runData(dataArgs)

	# cv
	cvArgs=[]
	cvArgs << "O=#{oPath}/cv"
	cvArgs << "D=#{oPath}/data"
	["alpha=","family=","T=","-verbose","-z","T=","param=","seed="].each{|key|
		if orgArgs[key]
			if key[0]=="-"
				cvArgs << key
			else
				cvArgs << "#{key}#{orgArgs[key]}"
			end
		end
	}
	runCV(cvArgs)

	# model building
	modelArgs=[]
	modelArgs << "D=#{oPath}/data"
	["alpha=","family=","T=","-verbose","-z","T=","param=","seed="].each{|key|
		if orgArgs[key]
			if key[0]=="-"
				modelArgs << key
			else
				modelArgs << "#{key}#{orgArgs[key]}"
			end
		end
	}

	lambdas=getLambdaMin1SE("#{oPath}/cv")
	lambdas.each{|lambda|
		ma=modelArgs
		ma << "lambda=#{lambda}"
		ma << "O=#{oPath}/model/lambda_#{lambda}"
		runModel(ma)
	}
end

# end message
MCMD::endLog($0+" "+ARGV.join(" "))


