#!/usr/bin/env ruby
# encoding: utf-8

# 1.1 fix the but about dimention mismatch: 2014/09/03
# 1.2 add -nocv mode, use JSON: 2015/01/11
# 1.3 add -z option, add original strings for xvar in coeff.csv : 2015/03/02
# 1.4 bug fix about NaN problem in specifing -z option : 2015/03/02
# 1.5 bug fix for key mismatching problem between x and y files : 2015/03/03
# 1.6 bug fix for prediction in logistic regression : 2015/03/27
$version="1.6"
$revision="###VERSION###"

def help

STDERR.puts <<EOF
----------------------------
mglmnet.rb version #{$version}
----------------------------
概要) Rのglmnetパッケージを利用した正則化法による回帰モデルの構築
特徴) 1) リッジ回帰、LASSO、elastic-netの正則化を指定可能
      2) 入力データは、サンプルID,featureID,値の3項目CSVデータ
      3) 交差検証(CV)によりlambdaを決定することで最適モデルを構築可
      4) 線形回帰、ロジスティック回帰、ポアッソン回帰など指定可能
      5) Rスクリプトを書く必要はない
用法1) モデル構築モード
       a)スパースマトリックスによる入力ファイル指定の場合
         mglmnet.rb [family=] [alpha=] i= k= x= [v=] c= y= exposure= O= [-z] [seed=] [-nocv] [param=] [T=] [-mcmdenv] [--help]
       a)マトリックスによる入力ファイル指定の場合
         mglmnet.rb [family=] [alpha=] i= x= y= exposure=            O= [-z] [seed=] [-nocv] [param=] [T=] [-mcmdenv] [--help]
用法2) 予測モード
       mglmnet.rb -predict [lambda=] i= I= o= [param=] [T=] [-mcmdenv] [--help]

  ### モデル構築モード
 
  ## 入力ファイルの指定は、スパースマトリックスによる方法とマトリックスによる方法の2通りある。
  ## (k=が指定されていれば、スパースマトリックスとみなされる)
  # a) スパースマトリックスによる入力ファイルの指定
	-sparse : このオプションが指定されて初めてスパースマトリックスモードとみなされる【必須】
  i=      : スパースマトリックス型入力データファイル名【必須】
  k=      : 1つのサンプルを表す項目名【必須】
  x=      : 説明変数を表す項目名【必須】
  v=      : 説明変数の値項目名【オプション】
          : 指定しなければ、全行1(すなわちダミー変数)となる。
  c=      : 目的変数データファイル名【選択必須】
  y=      : 目的変数の項目名【必須】
          : family=で指定した内容により以下に示す値である必要がある。
          :   gaussian: 実数
          :   poisson: 正の整数
          :   binomial: 2つのクラス値(文字列でも可)
          :   multinomial: 複数クラス値(文字列でも可)

  # b) マトリックスによる入力ファイルの指定
  i=      : マトリックス型入力データファイル名【必須】
  x=      : 説明変数項目名リスト【必須】
  y=      : 目的変数項目名【選択必須】

  O=      : 出力ディレクトリ名【必須】

  ## モデル構築関連
  family=  : リンク関数【デフォルト:"gaussian"】
           : gaussian: 線形回帰
           : poisson: ポアソン回帰
           : binomial: ロジスティック回帰
           : multinomial: 多項ロジスティック回帰
  alpha=   : elastic-netにおけるL1とL2正則化項の荷重【デフォルト:1.0】
           : 1.0でL1正則化、0でL2正則化(リッジ回帰)、0<alpha<1でelastic-net
  seed=    : 乱数の種(0以上の整数,交差検証に影響)【オプション:default=-1(時間依存)】
  -z       : 内部で説明変数を標準化する。
           :   スケールの異なる変数の係数を比較したい場合に利用する。
           :   -zをつけて作成されたモデルで予測することには意味がないことに注意する。
  -nocv    : 交差検証をしない *注)

  ### 予測モード(-predictを指定することで予測モードとして動作する)
  I=       : モデル構築モードでの出力先ディレクトリパス【必須】
           : 利用するファイルは以下のとおり。
           :   map_var2vno.csv: データの変換に利用
           :   model.robj: 回帰モデルRオブジェクト 
  lambda=  : 正則化項の重み【必須:複数指定可】
           :   0以上の実数値を与える以外に、以下の2つは特殊な意味を持つシンボルとして指定できる
           :   min: CVにおけるエラー最小モデルに対応するlambda
           :   1se: lambda.min+1*standard errorのモデルに対応するlambda
  o=       : 予測結果ファイル名
           :   key,目的変数予測値...
           : lambda=で指定した各lambdaに対応する予測値全てを出力する
  i=       : 予測対象入力ファイル名
           : フォーマットと項目名は、モデル構築モードで利用したものに完全に一致しなければならない。

  ## その他
	T=       : 作業ディレクトリ【デフォルト:"/tmp"】
	-mcmdenv : 内部のMCMDのコマンドメッセージを表示
	--help   : ヘルプの表示


  注) 交差検証(CV)をしてもしなくても、複数のlambda値に対する回帰係数の推定は行われる。
      CVをすることで、lambda別に構築される回帰モデルの予測エラーを推定する。
      そして、エラー最小化という意味における最適なlambdaを得ることが可能となる。
      よって-nocvを指定した場合、CVによる予測エラーの推定を行わないため、
      予測モードにおいてlambda="min,1se"は指定できない。

必要なソフトウェア)
  1) R
  2) Rのglmnetパッケージ

入力データ)
	例:
    key,var,val
    1,a,1
    1,c,2
    1,e,1
    2,c,2
    2,d,1
    3,a,2
    3,e,3
    3,d,6


モデル構築モードでの出力データ)
   1) model.robj        : 回帰モデルのRオブジェクト
   2) model_info.csv    : 回帰モデルに関する各種情報
   3) coef.csv          : lambda別係数一覧
   4) coef.png          : lambda別係数チャート
   5) lambda_stats.csv  : lambda別の各種情報(deviance,係数が非0のfeature数、推定誤差など)
   6) lambda_error.png  : lambda別エラーチャート
   7) map_var2vno.csv  : i=のx=項目とR内部のfeature番号の対応表
   8) scp.R             : 実行されたRスクリプト
   注: 6)は-nocvを指定時には出力されない
   注: 2)と5)は-nocvを指定時には一部出力されない

予測モードでの出力データ例)
  predict.csv
  key_num,id,lambda_1se,lambda_0.01,lambda_min
  1,20070701_5604,724.004406058175,743.068998688436,742.831291756625
  2,20070701_5605,832.022338347663,959.170798180323,957.54590188041
  3,20070701_5606,978.945506261202,1012.07069692832,1011.86134342746
  4,20070701_5607,866.708820321008,786.158661840733,787.19246417122

例)
  # モデル構築
  $ mglmnet.rb c=yaki_tanka.csv i=yaki_features.csv O=result1 k=id x=商品名 y=tanka -sparse

  # 上のモデル構築で使ったデータを使って予測
  $ mglmnet.rb -predict i=yaki_features.csv k=id x=商品名 I=result1 lambda=1se,0.01,min o=result1/predict.csv

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

# Rライブラリ実行可能確認
exit(1) unless(MCMD::chkRexe("glmnet"))

# separating the input file (ifile) into three following files
#   1) independent variables (x=) => xxvar
#   2) objective variable (y=) only when model building mode =>xxy
#   3) exposure variable if it's specified (exposure=) =>xxexposure
def matrix(ifile,key,var,xxvar,exposure,xxexposure,xxkey2num,yVar=nil,xxy=nil)
	MCMD::msgLog("#{File.basename($0)}: cleaning a matrix data `#{ifile}' ...")
	f=""
	f << "mcut f=#{var} i=#{ifile} o=#{xxvar}"
	system(f)

	f=""
	f << "mcut    f=#{key}:key i=#{ifile} |"
	f << "msortf  f=key |"
	f << "muniq   k=key |"
	f << "mnumber s=key a=key_num S=1 o=#{xxkey2num}"
	system(f)

	if xxy
		f=""
		f << "mcut f=#{yVar} i=#{ifile} o=#{xxy}"
		system(f)
	end

	if exposure
		f=""
		f << "mcut f=#{exposure} i=#{ifile} o=#{xxexposure}"
		system(f)
	end
end

# traデータからsparseMatrix用データを作成する
# 1) var2numがnullならば、ifileからvar2numを生成。指定されていれば、そのファイルを使って変換
# 2) key2num変換表を出力(key2num)
# 3) key,varがnumに変換されたデータを出力(row,col,val)
def smatrix(ifile,key,var,val,cFile,predictMode,var2num,key2num,xxrow,xxcol,xxval)
	MCMD::msgLog("#{File.basename($0)}: cleaning a sparse matrix data `#{ifile}' ...")

	wf=MCMD::Mtemp.new
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

	unless predictMode then
		MCMD::msgLog("#{File.basename($0)}: creating a mapping table of variables and their number...")
		f=""
		f << "mcut    f=var i=#{xxbase} |"
		f << "msortf  f=var |"
		f << "muniq   k=var |"
		f << "mnumber s=var a=vno S=1 o=#{var2num}"
		system(f)
	end

	MCMD::msgLog("#{File.basename($0)}: creating a mapping table of key and its number...")
	f=""
	f << "mcut    f=key i=#{xxbase} |"
	f << "msortf  f=key |"
	f << "muniq   k=key |"
	f << "mnumber s=key a=key_num S=1 o=#{key2num}"
	system(f)

	MCMD::msgLog("#{File.basename($0)}: creating index list and value list for initializing a sparse matrix...")
	f=""
	f << "mcut   f=key,var,val i=#{xxbase} |"
	f << "mjoin  k=key m=#{key2num} f=key_num |"
	f << "msortf f=var |"
	f << "mjoin  k=var m=#{var2num} f=vno o=#{xxa}"
	system(f)

	system "mcut f=key_num i=#{xxa} o=#{xxrow}"
	system "mcut f=vno     i=#{xxa} o=#{xxcol}"
	system "mcut f=val     i=#{xxa} o=#{xxval}"

	rowSize=MCMD::mrecount("i=#{key2num}")
	#colSize=MCMD::mrecount("i=#{var2num}")

	return rowSize
end

def mkYvar(cfile,key,yVar,xxkey2num,xxy)
	f=""
	f << "mcut f=#{key}:key,#{yVar}:y i=#{cfile} |"
	f << "msortf  f=key |"
	f << "mjoin   k=key m=#{xxkey2num} f=key_num |"
	f << "mcut    f=key_num,y |"
	f << "msortf  f=key_num%n o=#{xxy}"
	system(f)
end

def mkExposure(cfile,key,exposure,xxkey2num,xxexposure)
	if xxexposure
		f=""
		f << "mcut f=#{key}:key,#{exposure}:exposure i=#{cfile} |"
		f << "msortf  f=key |"
		f << "mjoin   k=key m=#{xxkey2num} f=key_num |"
		f << "mcut    f=key_num,exposure |"
		f << "msortf  f=key_num%n |"
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
##   xxmodel: model file (model.robj)
##   rowSize: the number of variables on dataset
##   lmdVar:  lambda values. It make prediction using the model with given each lambda value
##   exposureFile: exposure file (nil unless poisson regression)
##   xxoFile: output file name
def scpPrdSMX(xxmodel,rowSize,lmdVar,exposureFile,xxoFile,nocv)
	scp=""
	scp << "library(glmnet)\n"
	scp << "#####################################\n"
	scp << "## loading the model and make prediction\n"
	scp << "load(\"#{xxmodel}\")\n"
	if nocv then
		scp << "dims= c(#{rowSize},model$beta@Dim[1])\n"
	else
		scp << "dims= c(#{rowSize},model$glmnet.fit$beta@Dim[1])\n"
	end
	scp << "xMTX=sparseMatrix(i=row,j=col,x=val,dims=dims)\n"
	scp << "#####################################\n"
	scp << "## predict and output the result\n"
	if exposureFile
		scp << "exposureMTX= as.matrix(read.csv(\"#{exposureFile}\"))\n"
		scp << "prd = predict(model,xMTX,c(#{lmdVar}),offset=log(exposureMTX))\n"
	else
		scp << "prd = predict(model, xMTX,c(#{lmdVar}))\n"
	end
	scp << "write.csv(prd,file=\"#{xxoFile}\",quote=FALSE)\n"

	return scp
end

#######################
## prediction script using an existing model (matrix version)
##   xxmodel: model file (model.robj)
##   lmdVar:  lambda values. It make prediction using the model with given each lambda value
##   exposureFile: exposure file (nil unless poisson regression)
##   xxoFile: output file name
def scpPrdMTX(xxmodel,lmdVar,exposureFile,xxoFile)
	scp=""
	scp << "library(glmnet)\n"
	scp << "#####################################\n"
	scp << "## loading the model and make prediction\n"
	scp << "load(\"#{xxmodel}\")\n"
	scp << "#####################################\n"
	scp << "## setting sparseMatrix from csv data\n"
	scp << "#####################################\n"
	scp << "## predict and output the result\n"
	if exposureFile
		scp << "exposureMTX= as.matrix(read.csv(\"#{exposureFile}\"))\n"
		scp << "prd = predict(model,xMTX,c(#{lmdVar}),offset=log(exposureMTX))\n"
	else
		scp << "prd = predict(model,xMTX,c(#{lmdVar}))\n"
	end
	scp << "write.csv(prd,file=\"#{xxoFile}\",quote=FALSE)\n"

	return scp
end

def scpInpSMX(rowFile,colFile,valFile,yFile=nil)
	scp=""
	scp << "#####################################\n"
	scp << "## loading csv data and setting sparseMatrix\n"
	scp << "row = read.csv(\"#{rowFile}\")$key_num\n"
	scp << "col = read.csv(\"#{colFile}\")$vno\n"
	scp << "val = read.csv(\"#{valFile}\")$val\n"
	scp << "xMTX=sparseMatrix(i=row,j=col,x=val)\n"
	if yFile then
		scp << "#####################################\n"
		scp << "## setting csv data into a vector of objective valiable\n"
		scp << "yMTX= read.csv(\"#{yFile}\",header=T)\n"
		scp << "yMTX = yMTX$y # as a vector\n"
	end

	return scp
end

def scpInpMTX(xFile,yFile=nil)
	scp = ""
	scp << "#####################################\n"
	scp << "## loading csv data setting matrix\n"
	scp << "xMTX= as.matrix(read.csv(\"#{xFile}\"))\n"
	if yFile then
		scp << "yMTX= as.matrix(read.csv(\"#{yFile}\"))\n"
	end

	return scp
end

def scpExeSMX(family,alpha,param,exposureFile,nocv,doZ)
	cvStr="cv."
	cvStr="" if nocv

	scp=""
	scp << "#####################################\n" if doZ
	scp << "## standardizing x variables\n" if doZ
	scp << "xMTX=apply(xMTX,2,scale)\n" if doZ

	scp << "#####################################\n"
	scp << "## building a model with cross validation\n"
	scp << "xMTX=apply(xMTX,2,scale)\n" if doZ
	scp << "xMTX[is.na(xMTX)] <- 0\n" if doZ

	if exposureFile
		scp << "exposureMTX= as.matrix(read.csv(\"#{exposureFile}\"))\n"
		scp << "model = #{cvStr}glmnet(xMTX,yMTX,family=\"#{family}\",alpha=#{alpha},offset=log(exposureMTX))\n"
	else
		scp << "model = #{cvStr}glmnet(xMTX,yMTX,family=\"#{family}\",alpha=#{alpha})\n"
	end
	if nocv
		scp << "fit=model\n"
	else
		scp << "fit=model$glmnet.fit\n"
	end

	return scp
end

def scpExeMTX(family,alpha,param,exposureFile,nocv,doZ)
	cvStr="cv."
	cvStr="" if nocv

	scp=""
	scp << "#####################################\n" if doZ
	scp << "## standardizing x variables\n" if doZ
	scp << "xMTX=apply(xMTX,2,scale)\n" if doZ

	scp << "#####################################\n"
	scp << "## building a model with cross validation\n"
	if exposureFile
		scp << "exposureMTX= as.matrix(read.csv(\"#{exposureFile}\"))\n"
		scp << "model = #{cvStr}glmnet(xMTX,yMTX,family=\"#{family}\",alpha=#{alpha},offset=log(exposureMTX))\n"
	else
		scp << "model = #{cvStr}glmnet(xMTX,yMTX,family=\"#{family}\",alpha=#{alpha})\n"
	end
	if nocv
		scp << "fit=model\n"
	else
		scp << "fit=model$glmnet.fit\n"
	end

	return scp
end

def scpResult(modelFile,coefFile,coefPNG,constFile,lambdaFile,lambdaErrFile,infoFile)
	r_post_proc = <<EOF
#####################################
## output serialized objects of the model
save(model ,file="#{modelFile}")

#####################################
## output coefficients on each lambda
write.csv(as.matrix(fit$beta),file="#{coefFile}",quote=FALSE)
write.csv(as.matrix(fit$a0),file="#{constFile}",quote=FALSE)

png("#{coefPNG}")
 	plot(fit,"lambda")
supmsg=dev.off()

#####################################
## setting the model info
info=as.data.frame(fit$nobs)
colnames(info)=c("nobs")
info$colsize=fit$dim[2]
info$nulldev=fit$nulldev

#####################################
## output results of cv in csv format
stats=as.data.frame(c(1:length(model$lambda)))
colnames(stats)=c("sno")
stats$lambda=model$lambda
stats$df=model$df
stats$dev.ratio=fit$dev.ratio
# stats$dev.ratio=fit$dev.ratio[1:length(model$lambda)] 

stats$cvm=model$cvm
stats$cvsd=model$cvsd
stats$cvup=model$cvup
stats$cvlo=model$cvlo
write.csv(stats,"#{lambdaFile}",row.names=FALSE,quote=FALSE)

info$lambda_min=model$lambda.min
info$lambda_1se=model$lambda.1se
write.csv(info,"#{infoFile}",row.names=F,quote=FALSE)

png("#{lambdaErrFile}")
 	plot(model)
supmsg=dev.off()
EOF

	return r_post_proc
end

#################################################################################################
#### post processing

def coeff(xxcoef,xxconst,xxlambda,xxvar2num,isSMX,oPath)
	MCMD::msgLog("#{File.basename($0)}: summarizing coefficients on each lambda...")

	wf=MCMD::Mtemp.new
	xxnum2var = wf.file
	xxcoefv   = wf.file
	xxconstv  = wf.file
	xxmap     = wf.file

	# ,s0
	# V1,34.4221918005038
	# V2,42.2816648447219
	f=""
	f << "mnullto f=0 v=vno -nfn i=#{xxcoef} |"
	f << "msetstr v=coef a=fld |"
	f << "mcross  k=vno s=fld f=s* a=sno o=#{xxcoefv}"
	system(f)
	# vno,sno,coef
	# V1,s0,0
	# V1,s1,1.49990093015948
	# V1,s2,2.93162904818885
	# V1,s3,4.29828291361314

	# constant file (model$a0)
	# ,V1
	# s0,1.75
	# s1,0.625074302380394
	# s2,-0.448721786141637
	# s3,-1.47371218520986
	f=""
	f << "mnullto f=0 v=sno -nfn i=#{xxconst} |"
	f << "msetstr v=CONSTANT a=vno |"
	f << "mcut f=vno,sno,V1:coef o=#{xxconstv}"
	system(f)

	xxsno2lambda = wf.file
	f=""
	f << "mcut f=sno:sno_,lambda i=#{xxlambda} |"
	f << "mcal c='${sno_}-1' a=sno |"
	f << "msortf f=sno o=#{xxsno2lambda}"
	system(f)

	system("mcal c='\"V\"+$s{vno}' a=vnov i=#{xxvar2num} o=#{xxmap}") if isSMX

	f=""
	f << "mcat i=#{xxconstv},#{xxcoefv} |"
	f << "msed    f=sno c=s v= |"
	f << "mselstr f=coef v=0 -r|"
	f << "msortf  f=sno |"
	f << "mjoin   k=sno m=#{xxsno2lambda} f=lambda -n |"
	if isSMX then
		f << "mjoin   k=vno K=vnov m=#{xxmap} f=var:vname -n |"
		f << "mcut    f=lambda,vno,vname,coef |"
	else
		f << "mcut    f=lambda,vno,coef |"
	end
	f << "msortf  f=lambda%nr,vno o=#{oPath}/coef.csv"
	system(f)

end

#######################
## convert the predction file generated in R into output file(csv).
##   1) the first column is converted from ID made in R into key field name on input data.
##   2) each column correspond to prediction for each lambda specified.
##   3) exp(predicted value) if poisson
def outputPrediction(xxpredict,lmd,xxkey2num,key,family,ofile)

	fldNames=["0:key_num"]
	predFlds=[]
	i=0
	lmd.split(",").each{|ele|
		i+=1
		fldNames << "#{i}:lambda_#{ele}"
		predFlds << "lambda_#{ele}"
	}
	fldNames=fldNames.join(",")

	wf=MCMD::Mtemp.new
	xxnum2key=wf.file
	system "msortf f=key_num i=#{xxkey2num} o=#{xxnum2key}"

	# ,1,2,3
	# 1,724.004406058175,743.068998688436,742.831291756625
	# 2,832.022338347663,959.170798180323,957.54590188041
	f=""
	f << "mcut f=#{fldNames} -nfni i=#{xxpredict} |"
	f << "mdelnull f=key_num |"

	# exp(predict value) if poisson
	if family=="poisson"
		predFlds.each{|fld|
			f << "mcal c='exp(${#{fld}})' a=xxnew_#{fld} |"
			f << "mcut -r f=#{fld} |"
			f << "mfldname f=xxnew_#{fld}:#{fld} |"
		}

	# 1/(1+exp(predict value)) if binomial
	elsif family=="binomial"
		predFlds.each{|fld|
			f << "mcal c='1/(1+exp((-1)*${#{fld}}))' a=xxnew_#{fld} |"
			f << "mcut -r f=#{fld} |"
			f << "mfldname f=xxnew_#{fld}:#{fld} |"
		}
	end

	# join the key field
	f << "msortf   f=key_num |"
	f << "mjoin    k=key_num m=#{xxnum2key} f=key |"
	f << "msortf   f=key |"
	f << "mcut     f=key:#{key},lambda* o=#{ofile}"
	system(f)
end


#################################################################################################
#### Entry point

########################
## predict mode
if ARGV.index("-predict")
	args=MCMD::Margs.new(ARGV,"i=,I=,o=,c=,lambda=,-sparse,-predict,T=,-verbose,T=","i=,I=")

	# mcmdのメッセージは警告とエラーのみ
	ENV["KG_VerboseLevel"]="2" unless args.bool("-verbose")
	ENV["KG_ScpVerboseLevel"]="3" unless args.bool("-verbose")

	#ワークファイルパス
	if args.str("T=")!=nil then
		ENV["KG_TmpPath"] = args.str("T=").sub(/\/$/,"")
	end

	iPath = args.file("I=","r")
	params=nil
	File.open("#{iPath}/build_params.json","r"){|fpr|
		params=JSON.load(fpr)
	}

	ifile = args.file("i=","r")
	cfile = args.file("c=","r")
	var=params["var"]
	val=params["val"]
	key=params["key"]
	exposure=params["exposure"]
	family=params["family"]
	isSMX=params["sparse"]
	nocv=params["nocv"]

	ofile = args.file("o=","w")
	lmd   = args.str("lambda=","min")
	if nocv then
		if lmd=~/min/ or lmd=~/1se/
			raise "#ERROR# `min' or `1se' in lambda= parameter cannot be specified because the model built without cross-validation"
		end
	end
	lmdVar= lmd.gsub("min","model$lambda.min").gsub("1se","model$lambda.1se")

	wf=MCMD::Mtemp.new
	o={}
	o["xxscp"]   =wf.file
	o["xxofile"] =wf.file
	xxkey2num    =wf.file

	if isSMX then
		xxrow    =wf.file
		xxcol    =wf.file
		xxval    =wf.file
		xxexposure=nil
		xxexposure=wf.file if exposure

		rowSize=smatrix(ifile,key,var,val,nil,true,"#{iPath}/map_var2vno.csv",xxkey2num,xxrow,xxcol,xxval)
		mkExposure(cfile,key,exposure,xxkey2num,xxexposure)

		scp0=scpHeader()
		scp1=scpInpSMX(xxrow,xxcol,xxval)
		scp2=scpPrdSMX("#{iPath}/model.robj",rowSize,lmdVar,xxexposure,o["xxofile"],nocv)
	else
		xxvar=wf.file
		xxexposure=nil
		xxexposure=wf.file if exposure

		matrix(ifile,key,var,xxvar,exposure,xxexposure,xxkey2num)

		scp0=scpHeader()
		scp1=scpInpMTX(xxvar)
		scp2=scpPrdMTX("#{iPath}/model.robj",lmdVar,xxexposure,o["xxofile"])
	end	

	# writing the R script
	File.open(o["xxscp"],"w"){|fpw|
		fpw.puts "#{scp0}#{scp1}#{scp2}"
	}

	MCMD::msgLog("#{File.basename($0)}: executing R script...")
  if args.bool("-verbose") then
		system "R --vanilla -q < #{o['xxscp']}"
  else
    system "R --vanilla -q --slave < #{o['xxscp']} 2>/dev/null "
  end


	# output predicion
	outputPrediction(o["xxofile"],lmd,xxkey2num,key,family,ofile)

########################
#### model building mode
else

	args=MCMD::Margs.new(ARGV,"i=,c=,O=,k=,x=,v=,y=,alpha=,family=,exposure=,os=,T=,-verbose,-z,T=,param=,seed=,-sparse,-nocv","k=,x=,y=,i=,O=")

	# mcmdのメッセージは警告とエラーのみ
	ENV["KG_VerboseLevel"]="2" unless args.bool("-verbose")
	ENV["KG_ScpVerboseLevel"]="3" unless args.bool("-verbose")

	#ワークファイルパス
	if args.str("T=")!=nil then
		ENV["KG_TmpPath"] = args.str("T=").sub(/\/$/,"")
	end

	ifile =args.file("i=","r")
	cfile =args.file("c=","r")
	oPath =args.file("O=", "w")
	osfile=args.file("os=","r")

	# flag for sparse matrix or matrix
	isSMX=args.bool("-sparse")

	doZ=args.bool("-z")

	var=nil
	key=nil
	val=nil
	yVar=nil
	# ---- parameters for sparse matrix
	if isSMX then
		key  = args.field("k=" , ifile, nil , 1,1)["names"].join(",")
		var = args.field("x=", ifile, nil, 1,1)["names"][0]
		val = args.field("v=", ifile, nil, 1,1)
		val = val["names"][0] if val
		yVar = args.field("y=", cfile, nil, 1,1)["names"][0]
		exposure= args.field("exposure=",cfile,nil,1,1)
		exposure=exposure["names"][0] if exposure

	# ---- parameters for matrix
	else
		key  = args.field("k=", ifile, nil, 1)["names"].join(",")
		var  = args.field("x=", ifile, nil, 1)["names"].join(",")
		yVar = args.field("y=", ifile, nil, 1,1)["names"][0]
		exposure= args.field("exposure=",ifile,nil,1,1)
		exposure=exposure["names"][0] if exposure
	end

	# ---- other paramters
	alpha  = args.float("alpha=", 1.0, 0.0, 1.0)
	family = args.str("family=", "gaussian")
	seed   = args.int("seed=", -1)
	nocv   = args.bool("-nocv")
	param  = args.str("param=")
	param  = ","+param if param

	if family!="poisson" and exposure
		raise "#ERROR# `exposure=' can be specified with only `family=poisson'"
	end

	MCMD::mkDir(oPath)

	wf=MCMD::Mtemp.new
	o={}
	o["xxvar2num"] =wf.file
	o["xxmodel"]   =wf.file
	o["xxcoef"]    =wf.file
	o["xxcoefPNG"] =wf.file
	o["xxconst"]   =wf.file
	o["xxlambda"]  =wf.file
	o["xxlambdaPNG"]=wf.file
	o["xxinfo"]    =wf.file
	o["xxscp"]     =wf.file
	
	# convert tra file to sparse matrix
	# it's assumed as sparse matrix if cfile= is supplied.
	if isSMX then
		xxrow    =wf.file
		xxcol    =wf.file
		xxval    =wf.file
		xxy      =wf.file
		xxexposure=wf.file if exposure
		xxkey2num=wf.file

		smatrix(ifile,key,var,val,cfile,false,o["xxvar2num"],xxkey2num,xxrow,xxcol,xxval)
		mkYvar(cfile,key,yVar,xxkey2num,xxy)
		mkExposure(cfile,key,exposure,xxkey2num,xxexposure)

		scp0=scpHeader(seed)
		scp1=scpInpSMX(xxrow,xxcol,xxval,xxy)
		scp2=scpExeSMX(family,alpha,param,xxexposure,nocv,doZ)
		scp3=scpResult(o["xxmodel"],o["xxcoef"],o["xxcoefPNG"],o["xxconst"],o["xxlambda"],o["xxlambdaPNG"],o["xxinfo"])

		system "cp #{o['xxvar2num']} #{oPath}/map_var2vno.csv"
	# otherwise it's assumed as matrix data
	else
		xxvar=wf.file
		xxy  =wf.file
		xxexposure=nil
		xxexposure=wf.file if exposure
		xxkey2num=wf.file

		matrix(ifile,key,var,xxvar,exposure,xxexposure,xxkey2num,yVar,xxy)

		scp0=scpHeader(seed)
		scp1=scpInpMTX(xxvar,xxy)
		scp2=scpExeMTX(family,alpha,param,xxexposure,nocv,doZ)
		scp3=scpResult(o["xxmodel"],o["xxcoef"],o["xxcoefPNG"],o["xxconst"],o["xxlambda"],o["xxlambdaPNG"],o["xxinfo"])
	end

	# writing the R script
	File.open(o["xxscp"],"w"){|fpw|
		fpw.puts "#{scp0}#{scp1}#{scp2}#{scp3}"
	}
	MCMD::msgLog("#{File.basename($0)}: executing R script...")
  if args.bool("-verbose") then
		system "R --vanilla -q < #{o['xxscp']}"
  else
    system "R --vanilla -q --slave < #{o['xxscp']} 2>/dev/null "
  end



	# saving all results to oPath
	coeff(o["xxcoef"],o["xxconst"],o["xxlambda"],o['xxvar2num'],isSMX,oPath)
	system "cp #{o['xxmodel']}     #{oPath}/model.robj"
	system "cp #{o['xxcoefPNG']}   #{oPath}/coef.png"
	system "cp #{o['xxlambdaPNG']} #{oPath}/lambda.png" unless nocv
	system "cp #{o['xxinfo']}      #{oPath}/info.csv"
	system("cp #{o["xxscp"]}       #{oPath}/scp.R")
	system "mcut f=sno -r i=#{o['xxlambda']} o=#{oPath}/lambda.csv"

	# 項目名
	kv={"var"=>var,"val"=>val,"key"=>key,"exposure"=>exposure,"family"=>family,"sparse"=>isSMX,"nocv"=>nocv}
	File.open("#{oPath}/build_params.json","w"){|fpw|
		JSON.dump(kv,fpw)
	}

end

# end message
MCMD::endLog(args.cmdline)

