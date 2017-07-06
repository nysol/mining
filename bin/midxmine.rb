#!/usr/bin/env ruby
# encoding: utf-8

# 1.0 initial release: 2017/01/15
$version="1.0"
$revision="###VERSION###"

def help

STDERR.puts <<EOF
----------------------------
midxmine.rb version #{$version}
----------------------------
description) construct a regression model with optimally indexed itemset sequences
features) 1) using elastic-net regression (ridge to lasso regression)
          2) exploring the best alphabet-index, which is mapping function from item to group
          3) enumerate frequent itemset sequences, and use them as input variables for a model
          4) linear regression and logistic regression can be chosed
usage1) model building mode
  midxmine.rb -noidx i= tid= time= item= s= c= class= [family=binomial] [alpha=1.0] [idxSize=2] [seed=] O= [T=] [-mcmdenv] [--help]
usage2) prediction mode (not imprementaed yet)
       mglmnet.rb -predict i= I= o= [T=] [-mcmdenv] [--help]

  ### model building mode
  # parameters for input data
  i=      : transaction data file (mandatory)
  tid=    : field name for transaction ID in i= file (mandatory)
  time=   : field name for time in i= file (mandatory)
  itme=   : field name for item in i= file (mandatory)

  # parameters for class data
  c=      : target variable file (mandatory)
          : this file have to have the same field name as tid= in i= file (mandatory)
  class=  : field name for target variable in c= file (mandatory)

  # parameters for itemset sequence enumeration
  s=      : minimum support for enumerating itemset sequences (mandatory)

  # parameters for regression
  family  : link function for generalized linear regression model
            "binomial" or "gaussian" can be chosen
  alpha   : weight of L1 and L2 regulalization in elastic-net
              1.0: lasso regression (L1)
              0.0: ridge regression (L2)

  # parameters for indexing
  idxSize : index size
  seed=   : random seed for initial index

  O=      : directory name for ouput (mandatory)

  ### prediction mode (not impremented yet)

  ### other parameters
  T=       : directory name for temporal files (default=/tmp)
  mcmdenv : show messages of mcmd
  -help   : show help

necessary software)
  1) R
  2) glmnet package in R
  2) arulesSequences package in R

example)
$ cat zaki.csv
tid,time,item
1,10,C
1,10,D
1,15,A
1,15,B
1,15,C
1,20,A
1,20,B
1,20,F
1,25,A
1,25,C
1,25,D
1,25,F
2,15,A
2,15,B
2,15,F
2,20,E
3,10,A
3,10,B
3,10,F
4,10,D
4,10,G
4,10,H
4,20,B
4,20,F
4,25,A
4,25,G
4,25,H
$ cat zaki_c.csv
tid,class
1,1
2,1
3,0
4,0

$ midxmine.rb i=zaki.csv c=zaki_c.csv O=result1 tid=tid item=item time=time class=class idxSize=2 seed=111 s=0.1↩

$ ls result1
 alphabetIndex.csv
 beta.txt
 coef.png
 const.txt
 info.txt
 lambda.png
 model.obj

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
exit(1) unless(MCMD::chkRexe("arulesSequences"))

class Index
	attr_reader :size
	def show
		puts "@ifile=#{@ifile}"
		puts "@idxSize=#{@idxSize}"
		puts "@seed=#{@seed}"
		puts "@alphabets=#{@alphabets}"
	end

	# constructor
	def initialize(ifile,idxSize,seed)
		@ifile=ifile
		@idxSize=idxSize

		# setting up random object
		unless seed
			@seed=Random.new_seed
		else
			@seed=seed
		end
		@random = Random.new(@seed)
		@done=[]

		# setting alphabet vector and its size
		temp=MCMD::Mtemp.new
		xxitem=temp.file
		f=""
		f << "mcut f=item i=#{ifile} |"
		f << "muniq k=item o=#{xxitem}"
		system(f)
		iCSV=MCMD::Mcsvin.new("i=#{xxitem}")
		@alphabets=[]
		iCSV.each{|flds|
			@alphabets << flds["item"]
		}
		@size=@alphabets.size
	end

	# generate random index
	def firstIdx(noidx)
		index=nil
		if noidx
			index=[]
			(0...@alphabets.size).each{|i|
				index << i
			}
		else
			begin
				index=[]
				itemset=Set.new
				(0...@alphabets.size).each{|i|
					num=@random.rand(@idxSize)
					itemset << num
					index << num
				}
			end while itemset.size < @idxSize
		end
		return index
	end

	# enumerating adjacents indexes
	# indexes processed before will be skipped
	def adjacents(index,noidx)
		adjIndexes=[]
		if noidx
			adjIndexes << index
		else
			(0...index.size).each{|pos|
				[-1,+1].each{|dir|
					num=index[pos]+dir
					next if num < 0 or num >= @idxSize
					adjIndex=[]
					(0...index.size).each{|i|
						if pos==i
							adjIndex << num
						else
							adjIndex << index[i]
						end
					}
					if not @done.index(adjIndex)
						adjIndexes << adjIndex
					else
						@done << adjIndex
					end
				}
			}
		end
		return adjIndexes
	end

	# write alphabet-index to oFile
	def writeAlphaIndex(index,oFile)
		MCMD::Mcsvout.new("o=#{oFile} f=alphabet,index"){|oCSV|
			(0...@alphabets.size).each{|i|
				oCSV.write([@alphabets[i],index[i]])
			}
		}
	end
end

# convert original transaction data to one with indexed item
def convTra(ifile,idxObj,index,convTraFile)
	temp=MCMD::Mtemp.new
	xxmf=temp.file
	idxObj.writeAlphaIndex(index,xxmf)
	f=""
	f << "mjoin k=item K=alphabet m=#{xxmf} f=index i=#{ifile} |"
	f << "mcut f=tid,time,index |"
	f << "muniq k=tid,time,index |"
	f << "mtra k=tid,time f=index |"
	f << "mvcount vf=index:size |"
	f << "mcut f=tid,time,size,index -nfno o=#{convTraFile}"
	system(f)
end

# estimate the best lambda
# 1. enumerate frequent sequences using all data
# 2. construct regression model with the sequences as input variable
#    cross validation is used for getting the best lambda
# 3. return deviance and lambda
def mkCVmodel(convTra,minSupport,yFile,seed)
system "cp #{convTra} xxconvTra"
	temp=MCMD::Mtemp.new
	xxscp=temp.file
	xxdev=temp.file
	xxlam=temp.file
	scp= <<"EOS"
	library(arulesSequences)
	library(glmnet)
EOS
	scp << "\tset.seed(#{seed})\n" if seed

	scp << <<"EOS"
	x <- read_baskets(con="#{convTra}", sep=",",info=c("sequenceID","eventID","SIZE"))
	as(x, "data.frame")
	s1 <- cspade(x, parameter = list(support = #{minSupport}), control = list(verbose = TRUE))
	#as(s1, "data.frame")
	xMTX=as(as(supportingTransactions(s1,x),"ngCMatrix"),"matrix")
	#print(xMTX)
	yMTX=as.matrix(read.csv(\"#{yFile}\"))
	model = cv.glmnet(xMTX,yMTX,family=\"binomial\",alpha=1.0)
	mm=which(model$lambda==model$lambda.min)
	write.table(model$cvm[mm]   ,"#{xxdev}", quote=F, col.names=F,row.names=F)
	write.table(model$lambda.min,"#{xxlam}", quote=F, col.names=F,row.names=F)
	#print(mm)
	#print(model$lambda)
	#print(model$lambda.min)
	#print(model$cvm)
	#print(model$cvm[mm])
	#print(str(model))
	#print(summary(model))
	#sink()
EOS

	File.open(xxscp,"w"){|fpw| fpw.puts scp}
	system "R --vanilla -q --slave < #{xxscp} &>/dev/null"
	#system "R --vanilla -q < #{xxscp}"
	# if all fields have same value for all records, glmnet fail and it doesn't output the result.
	dev=Float::MAX
	lam=nil
	if File.exists?(xxdev)
		dev=`cat #{xxdev}`.strip.to_f
		lam=`cat #{xxlam}`.strip.to_f
	end
	return dev,lam
#system "cp #{convTra} xxconvTra"
#system "cp #{xxscp} xxscp"
#	puts scp
end

# construct a regression model with specified lambda
def mkModel(convTra,lam,minSupport,yFile,oPath)
	temp=MCMD::Mtemp.new
	xxscp=temp.file
	xxdev=temp.file
	xxlam=temp.file
	scp= <<"EOS"
	library(arulesSequences)
	library(glmnet)
	x <- read_baskets(con="#{convTra}", sep=",",info=c("sequenceID","eventID","SIZE"))
	as(x, "data.frame")
	s1 <- cspade(x, parameter = list(support = #{minSupport}), control = list(verbose = TRUE))
	#as(s1, "data.frame")
	xMTX=as(as(supportingTransactions(s1,x),"ngCMatrix"),"matrix")
	#print(xMTX)
	yMTX=as.matrix(read.csv(\"#{yFile}\"))

	cv = cv.glmnet(xMTX,yMTX,family=\"binomial\",alpha=1.0)
	png("#{oPath}/lambda.png")
		plot(cv)
	supmsg=dev.off()

	model = glmnet(xMTX,yMTX,family=\"binomial\",alpha=1.0,lambda=#{lam})
	save(model ,file="#{oPath}/model.obj")
	write.csv(as.matrix(model$a0),file="#{oPath}/const.txt",quote=FALSE)
	write.csv(as.matrix(model$beta),file="#{oPath}/beta.txt",quote=FALSE)
	png("#{oPath}/coef.png")
		plot(model,"lambda")
	supmsg=dev.off()

	info=as.data.frame(model$nobs)
	colnames(info)=c("nobs")
	info$lambda=#{lam}
	info$devRatio=model$dev.ratio
	info$nulldev=model$nulldev
	write.table(info,"#{oPath}/info.txt", quote=F, sep=",", col.names=T,row.names=F, append=F)
EOS

	File.open(xxscp,"w"){|fpw| fpw.puts scp}
	system "R --vanilla -q --slave < #{xxscp} &>/dev/null"
	#system "R --vanilla -q < #{xxscp}"
	# if all fields have same value for all records, glmnet fail and it doesn't output the result.
	dev=Float::MAX
	lam=nil
	if File.exists?(xxdev)
		dev=`cat #{xxdev}`.strip.to_f
		lam=`cat #{xxlam}`.strip.to_f
	end
	#p dev
	#p lam
	return dev,lam
#system "cp #{convTra} xxconvTra"
#system "cp #{xxscp} xxscp"
#	puts scp
end

#################################################################################################
#### Entry point
st=Time.new

########################
## predict mode
if ARGV.index("-predict")
;
########################
#### model building mode
else
	args=MCMD::Margs.new(ARGV,"-noidx,i=,c=,tid=,time=,item=,s=,class=,alpha=,family=,O=,idxSize=,seed=,mp=,T=,-verbose,T=,seed=","tid=,item=,time=,c=,s=,class=,i=,O=")

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

	tid  = args.field("tid=" , ifile, nil , 1,1)["names"].join(",")
	item = args.field("item=", ifile, nil , 1,1)["names"].join(",")
	klass= args.field("class=",cfile, nil , 1,1)["names"].join(",")
	time = args.field("time=", ifile, nil , 1,1)
	
	if time
		time=time["names"].join(",")
	end

	# ---- other paramters
	alpha  = args.float("alpha=", 1.0, 0.0, 1.0)
	family = args.str("family=", "binomial")
	minSupport= args.int("s=")
	seed   = args.int("seed=")
	idxSize= args.int("idxSize=", 2)
	mp     = args.int("mp=", 8)
	noidx  = args.bool("-noidx")
	#param  = args.str("param=")
	#param  = ","+param if param
	MCMD::mkDir(oPath)

	wf=MCMD::Mtemp.new
	xxifile  =wf.file
	xxyfile  =wf.file
	xxconvTra=wf.file
	xxrsl    =wf.file

	f=""
	f << "msortf f=#{tid} i=#{cfile} |"
	f << "mcut f=#{klass}:klass o=#{xxyfile}"
	system(f)

	if time
		f=""
		f << "mcut f=#{tid}:tid,#{time}:time,#{item}:item i=#{ifile} |"
		f << "muniq k=tid,time,item |"
		f << "msortf f=tid,time | mfldname -q o=#{xxifile}"
		system(f)
	else
		f=""
		f << "mcut f=#{tid}:tid,#{item}:item i=#{ifile} |"
		f << "muniq k=tid,item |"
		f << "msortf f=tid o=#{xxifile}"
		system(f)
	end

	idxObj=Index.new(xxifile,idxSize,seed)
	bestMSE=Float::MAX
	bestLAM=nil
	bestIDX=idxObj.firstIdx(noidx)
	STDERR.puts "#{bestIDX.join("")} initial index"

	while true
		indexes=idxObj.adjacents(bestIDX,noidx)
		# find the better model in multiple indexes
		(0...indexes.size).to_a.meach(mp){|i|
			convTra(xxifile,idxObj,indexes[i],"#{xxconvTra}_#{i}")
			dev,lam=mkCVmodel("#{xxconvTra}_#{i}",minSupport,xxyfile,seed)
			File.open("#{xxrsl}_#{i}", 'w'){|fpw|
				JSON.dump([dev,lam], fpw)
			}
			STDERR.puts "#{indexes[i].join("")} deviance[#{i}]=#{dev}"
		}
		updated=false
		(0...indexes.size).each{|i|
			dev=lam=nil
			File.open("#{xxrsl}_#{i}"){|fpr|
				dev,lam=JSON.load(fpr)
			}
			if bestMSE>dev
				updated=true
				bestMSE=dev
				bestLAM=lam
				bestIDX=indexes[i]
			end
		}
		system "rm -r #{xxrsl}_*"
		if updated
			STDERR.puts "#{bestIDX.join("")} improved (deviance=#{bestMSE} lambda=#{bestLAM})"
		else
			STDERR.puts "not improved and finished for exploring"
			break
		end
	end

	if bestLAM
		convTra(xxifile,idxObj,bestIDX,xxconvTra)
		mkModel(xxconvTra,bestLAM,minSupport,xxyfile,oPath)
		idxObj.writeAlphaIndex(bestIDX,"#{oPath}/alphabetIndex.csv")
	else
		STDERR.puts "it could not find any good model"
	end
end

	STDERR.puts "elapsed time : #{Time.new-st} seconds"

# end message
MCMD::endLog(args.cmdline)

