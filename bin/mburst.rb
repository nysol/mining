#!/usr/bin/env ruby
# encoding:utf-8

require 'fileutils'
require 'rubygems'
require 'nysol/mcmd'

$version=1.0
$revision="###VERSION###"

def help

STDERR.puts <<EOF
----------------------------
mburst.rb version #{$version}
----------------------------
概要) HMMによるburst検知プログラム
特徴) 1) 分布のパラメータの変化を検知する
      2) 確率分布としては指数分布、ポアソン分布、正規分布、二項分布に対応
書式) mburst.rb f= dist=exp|poisson|gauss|binom [s=] [p=] i= [o=] [--help]

例) mburst.rb f=interval dist=exp i=burstExp.csv o=output.csv

  i=     : 入力ファイル名【必須】
  o=     : 出力ファイル名【オプション:defaultは標準出力】
	d=     : デバッグ情報を出力するファイル【オプション】
  dist=  : 仮定する分布名称(exp:指数関数,poisson:ポアソン分布,gauss:正規分布,binom:二項分布)【必須】
  f=     : burst検知対象となる数値項目名(i=上の項目名)【必須】
  param= : 定常状態における分布のパラメータ。注1参照【オプション】
  pf=    : 定常状態における分布のパラメータ項目名(i=上の項目名)注1参照【オプション】
	s=     : burstスケール(詳細は注2参照)【オプション:default=2.0】
  p=     : 同一状態遷移確率(この値を高くするとbusrtしにくくなる。詳細は注3参照)【オプション:default=0.6】

  n=  : dist=binomの場合の試行回数【n= or nf=いずれかを指定】
  nf= : dist=binomの場合の試行回数の項目名
	v=  : dist=gaussの場合の分散値(指定がなければf=項目のデータから推定)
	nv= : dist=gaussの場合の分散の項目名
  --help : ヘルプの表示

  注1) 定常状態における分布のパラメータ(母数)の与え方は以下の３通り。
	     1) para=で指定した値とする。
	     2) pf=で指定した項目の値を用いる。時刻に依存してパラメータが異なることが仮定できる場合のため。
	     3) para=,pf=の指定がなければ、f=で指定した値から自動的に計算される。

  注2) 定常状態、burst状態における分布パラメータの計算方法は以下のとおり。
	S: s=で指定した値、n:データ件数、x_i: f=でしていした項目のi行目の値
	exp:     確率密度関数f(x)=λ*exp(-λx)、パラメータはλ(平均イベント発生回数)
	         定常(state0)状態λ0=n/Σx_i
	         burst(state1)状態λ1=λ0*S
	poisson: 確率関数f(x)=λ^x*exp(-λ)/x!、パラメータはλ(平均イベント発生回数)
	         定常(state0)状態λ0=Σx_i/n
	         burst(state1)状態λ1=λ0*S
	gauss:   確率密度関数: f(x)= 1/√2πσ^2 exp(-(x-μ)^2/2σ^2)、パラメータはμ(平均)
	         m=Σx_i/n、v=Σ(x_i-m)^2/nとすると、
	         下側burst(state-)状態μ- =m-sqrt(v)*S
	         定常(state0)状態μ0 =m
	         上側burst(state+)状態μ+ =m+sqrt(v)*S
	binom:   確率関数: f(x)=(T choose x)p^x(1-p)^(T-x):パラメータはp(成功確率)
	         定常(state0)状態p0=(Σx_i/n)/T  (平均成功回数/試行回数)
	         burst(state1)状態p1=S/((1-p0)/p0+S)

  注3) 状態遷移確率の設定方法。
	p: p=で指定した値
	exp, poisson, binom:
		prob(state0→state0)=prob(state1→state1)
		prob(state0→state1)=prob(state1→state0)=1-p 
	gauss:
		prob(state-1→state-1)=prob(state0→state0)=prob(state1→state1)=p 
		prob(state0→state-1)=prob(state0→state1)=prob(state2→state2)=(1-p)/2
		prob(state-1→state0)=prob(state1→state0)=(1-p)/3*2
		prob(state-1→state1)=prob(state1→state-1)=(1-p)/3

Copyright(c) NYSOL 2012- All Rights Reserved.
EOF
exit
end

def ver()
	$revision ="0" if $revision =~ /VERSION/
	STDERR.puts "version #{$version} revision #{$revision}"
	exit
end




help() if ARGV.size <= 0
help() if ARGV[0]=="--help"
ver() if ARGV[0]=="--version"

# パラメータ設定
args=MCMD::Margs.new(ARGV,"i=,o=,d=,f=,dist=,s=,p=,pf=,n=,nf=,v=,vf=,param=","i=,o=,f=,dist=")

iFile = args.file("i=","r")
dFile = args.file("d=","w",nil)
oFile = args.file("o=","w")
fName = args.field("f=",iFile)
fName = fName["names"].join(",") if fName
pName = args.field("pf=",iFile)
pName = pName["names"].join(",") if pName
nName = args.field("nf=",iFile)
nName = nName["names"].join(",") if nName
vName = args.field("vf=",iFile)
vName = vName["names"].join(",") if vName

distType   = args.str("dist=")
unless ["exp","poisson","gauss","binom"].index(distType)
	raise "`dist=' takes `exp',`poisson',`gauss' or `binom'"
end

burstScale = args.float("s=",2.0)
iProb      = args.float("p=",0.6)
trial      = args.float("n=")
var        = args.float("v=")
param      = args.float("param=")

if distType!="binom" and (trial or nName)
		raise "`n=' or `nf=' is a parameter for binom burst."
end

if distType!="gauss" and (var or vName)
		raise "`v=' or `vf=' is a parameter for gauss burst."
end

if distType=="binom"
	if trial==nil and nName==nil
		raise "`n=' or `nf=' have to be specified in binom burst."
	end
	if nName!=nil and not (param or pName)
		raise "`param=' or `pf=' have to be specified with `nf=' in binom burst."
	end
end

if distType=="gauss"
	if (param!=nil and var==nil) or (param==nil and var!=nil)
		raise "`param=' and `var=' have to be specified together in gaussian burst."
	end
end

##########################
module MDM

class DistBurst
	attr_reader :data
	attr_reader :burstSymbol

	def initialize(name)
		@name=name
		@data=[]
		@dpar=nil
		@dpar=[] if @parFld
		# 入力ファイルを項目別にメモリにセット
		MCMD::Mcsvin.new("i=#{@fname}"){|csv|
			csv.each{|flds|
				v=flds[@valFld].to_f
				p=flds[@parFld].to_f if @parFld
				@data << v
				@dpar << p if @parFld
			}
		}
		# burst項目の出力シンボル。
		# 状態0と状態1をburst項目として0,1として出力。
		# このシンボル表を変更するのであれば継承クラスで独自に定義する。
		@burstSymbol=["0","1"]
	end

	# 初期確率
	# 2状態の確率分布のみ対応。それ以外は継承クラスで独自に定義する。
	def initProbLn()
		initProbLn=[ln(1.0), ln(0.0)]
		return initProbLn
	end

	# 遷移確率
	# 2状態の遷移確率のみ対応。それ以外は継承クラスで独自に定義する。
	#                       to
	#                 0              1
	# from 0 transProbLn[0][0] transProbLn[0][1]
	#      1 transProbLn[1][0] transProbLn[1][1]
	def calTransProbLn(inertiaProb)
		transProbLn=[]
		transProbLn << [ln(    inertiaProb), ln(1.0-inertiaProb)]
		transProbLn << [ln(1.0-inertiaProb), ln(    inertiaProb)]
		return transProbLn
	end

	# 自然対数の計算(ln(0)=-9999.0で定義
	def ln(prob)
		ret=-9999.0
		if prob>0
			ret=Math::log(prob)
		end
		return ret
	end

	def logsum(from,to)
		sum=0.0
		(from.to_i..to.to_i).each{|x|
			sum+=Math::log(x)
		}
		return sum
	end

	def show(fpw=STDERR)
		fpw.puts "### MDM::DistBurst class"
		fpw.puts "  入力: #{@fname}, 値項目名:#{@valFld}"
		fpw.puts "  確率(密度)関数名:#{@name}"
		fpw.puts "  データ件数: #{@data.size}"
		fpw.puts "  @data=#{@data.join(',')}"
	end
end

#-----------------------------------------------------------
# 指数分布(事象発生間隔分布)
# λ: 時間あたりの事象の平均発生回数
# x: 事象の発生間隔
# f(x)=λe^{-λx}
class ExpBurst < DistBurst
	def initialize(fname,valFld,parFld,param)
		@fname  =fname
		@valFld =valFld
		@parFld =parFld
		@param  =param
		super("exp")

		# パラメータのセット
		# 定常状態平均到着数
		@term=0.0
		@data.each{|v| @term+=v}

		unless @parFld
			if @param!=nil
				@lamda=param
			else
				@lamda=@data.size.to_f/@term
			end
		end
	end

	# 指数分布の確率密度関数: f(x)=λexp(-λx)
	# log f(x) = logλ - λx
	def probFunc(x,lamda)
		return Math::log(lamda) - lamda*x
	end

	def stateProbLn(burstScale)
		@burstScale=burstScale
		stateProbLn=[]
		(0...@data.size).each{|i|
			x=@data[i]
			p=nil
			if @dpar
				p=@dpar[i]
			else
				p=@lamda
			end
			stateProbLn << [ probFunc(x,p), probFunc(x,p*@burstScale) ]
		}
		return stateProbLn
	end

	def show(fpw=STDERR)
		super(fpw)
		fpw.puts "### MDM::ExpBurst < DistBurst class"
		fpw.puts "  @lamda: #{@lamda}, @param: #{@param}"
		fpw.puts "  @dpar: #{@dpar}"
		fpw.puts "  @term : #{@term}"
	end
end

#-----------------------------------------------------------
# ポアソン分布(事象発生数分布)
# λ: 時間あたりの事象の平均発生回数
# x: 事象の発生間隔
# 確率関数: f(x)=λ^x*exp(-λ)/x!
class PoissonBurst < DistBurst
	def initialize(fname,valFld,parFld,param)
		@fname  =fname
		@valFld =valFld
		@parFld =parFld
		@param  =param
		super("poisson")

		# パラメータのセット
		# 定常状態平均到着数
		@count=0.0
		@data.each{|v| @count+=v}

		unless @parFld
			if @param!=nil
				@lamda=param
			else
				@lamda=@count/@data.size.to_f
			end
		end
	end

	# ポアソン分布の確率関数
	# f(x)=λ^x/x!*exp(-λ)
	# log f(x) = x*logλ-λ-Σ_{i=1..x}i
	def probFunc(x,lamda)
		if x==0 # 0!=1のため
			return -lamda
		else
			return x*Math::log(lamda) - Math::log((1.0+x)*x/2.0) - lamda
		end
	end

	def stateProbLn(burstScale)
		@burstScale=burstScale
		stateProbLn=[]
		(0...@data.size).each{|i|
			x=@data[i]
			p=nil
			if @dpar
				p=@dpar[i]
			else
				p=@lamda
			end
			stateProbLn << [ probFunc(x,p), probFunc(x,p*@burstScale) ]
		}
		return stateProbLn
	end

	def show(fpw=STDERR)
		super(fpw)
		fpw.puts "### MDM::PoissonBurst < DistBurst class"
		fpw.puts "  @lamda: #{@lamda}, @param: #{@param}"
		fpw.puts "  @dpar: #{@dpar}"
		fpw.puts "  @count: #{@count}"
	end
end

#-----------------------------------------------------------
# 正規分布(誤差分布)
# mean: 平均
# var: 分散
# 確率密度関数: f(x)= 1/√2πσ^2 exp(-(x-μ)^2/2σ^2
class GaussBurst < DistBurst
	def initialize(fname,valFld,parFld,param,varFld,var)
		@fname  =fname
		@valFld =valFld
		@parFld =parFld
		@param  =param
		super("gauss")

		# パラメータのセット
		# 定常状態平均値と不偏分散
		@mean=nil
		@var=nil
		if @parFld
			@var=[]
			# 分散項目読み込み
			MCMD::Mcsvin.new("i=#{@fname}"){|csv|
				csv.each{|flds|
					v=flds[varFld].to_f
					@var << v
				}
			}
		else
			if @param!=nil
				@mean=@param
				@var=var
			else
				@mean=0.0
				@var=0.0
				@data.each{|v| @mean+=v}
				@mean/=@data.size.to_f
				@data.each{|v| @var+=(v-@mean)**2}
				@var/=(@data.size-1).to_f
			end
		end
		
		# gauss分布burstでは、状態0,1,2を-1,0,1で出力
		@burstSymbol=["-1","0","1"]
	end

	# 初期確率
	def initProbLn()
		initProbLn=[ln(0.0), ln(1.0), ln(0.0)]
		return initProbLn
	end

	# 遷移確率
	#                       to
	#                 -              0                 +
	#      - transProbLn[0][0] transProbLn[0][1] transProbLn[0][2]
	# from 0 transProbLn[1][0] transProbLn[1][1] transProbLn[1][2]
	#      + transProbLn[2][0] transProbLn[2][1] transProbLn[2][2]
	def calTransProbLn(inertiaProb)
		transProbLn=[]
		transProbLn << [ln(     inertiaProb     ), ln((1.0-inertiaProb)/3.0*2.0), ln((1.0-inertiaProb)/3.0)]
		transProbLn << [ln((1.0-inertiaProb)/2.0), ln(     inertiaProb         ), ln((1.0-inertiaProb)/2.0)]
		transProbLn << [ln((1.0-inertiaProb)/3.0), ln((1.0-inertiaProb)/3.0*2.0), ln(     inertiaProb     )]
		return transProbLn
	end

	# 正規分布の確率密度関数
	# f(x)= 1/√2πσ^2 exp(-(x-μ)^2/2σ^2
	# log f(x) = log1 - (1/2)log(2πσ^2) - (x-u)^2/2σ^2
	def probFunc(x, mu, sigma2)
		return Math.log(1.0)-Math.log(2.0*Math::PI*sigma2)/2.0-((x-mu)**2.0)/(2.0*sigma2)
	end

	def stateProbLn(burstScale)
		@burstScale=burstScale
		stateProbLn=[]
		(0...@data.size).each{|i|
			x=@data[i]
			p=nil
			if @dpar
				p=@dpar[i]
				v=@var[i]
			else
				p=@mean
				v=@var
			end
			stateProbLn << [ probFunc(x,p-Math.sqrt(v)*burstScale,v), probFunc(x,p,v), probFunc(x,p+Math.sqrt(v)*burstScale,v)]
		}
		return stateProbLn
	end

	def show(fpw=STDERR)
		super(fpw)
		fpw.puts "### MDM::GaussBurst < DistBurst class"
		fpw.puts "  @mean: #{@mean}, @param: #{@param}"
		fpw.puts "  @dpar: #{@dpar}"
		fpw.puts "  @var: #{@var}"
	end
end

#-----------------------------------------------------------
# 二項分布(成功数分布)
# p: 成功確率
# x: 成功回数
# 確率関数: f(x)=nCx*p^x*(1-p)^(n-x)
class BinomBurst < DistBurst
	def initialize(fname,valFld,parFld,param,tryFld,trial)
		@fname  =fname
		@valFld =valFld
		@parFld =parFld
		@param  =param
		super("binom")

		# パラメータのセット
		# 定常状態平均成功数

		@trial=nil
		if tryFld
			@trial=[]
			MCMD::Mcsvin.new("i=#{@fname}"){|csv|
				csv.each{|flds|
					v=flds[tryFld].to_f
					@trial << v
				}
			}
		else
			@trial=trial.to_f
		end

		@prob =nil
		unless @parFld
			if @param!=nil
				@prob=param
			else
				avg=0.0
				@data.each{|v| avg+=v}
				avg=avg/@data.size.to_f
				@prob=avg/@trial
			end
		end
	end

	# 二項分布の確率関数
	# f(x)=nCx*p^x*(1-p)^(n-x)
	# log f(x) = Σ_{i=n..n-x+1}log(i) - Σ_{i=x..1}log(i) + x*log(p) + (n-x)*log(1-p)
	def probFunc(x,prob,trial)
		return logsum(trial-x+1,trial) - logsum(1,x) + x*Math::log(prob)+(trial-x)*Math::log(1-prob)
	end

	def stateProbLn(burstScale)
		@burstScale=burstScale
		stateProbLn=[]
		(0...@data.size).each{|i|
			x=@data[i]
			p=nil
			if @dpar
				p=@dpar[i]
			else
				p=@prob
			end
			if @trial.class.name=="Array"
				n=@trial[i]
			else
				n=@trial
			end
			stateProbLn << [ probFunc(x,p,n), probFunc(x,@burstScale/((1.0-p)/p+@burstScale),n) ]
		}
		return stateProbLn
	end

	def show(fpw=STDERR)
		super(fpw)
		fpw.puts "### MDM::BinomBurst < DistBurst class"
		fpw.puts "  @prob: #{@mean}, @param: #{@param}"
		fpw.puts "  @dpar: #{@dpar}"
		fpw.puts "  @trial: #{@trial}"
	end
end


#########################################################
# バーストクラス
#########################################################
class Burst

private

	def initialize(dist)
		@time=[]        # メッセージの到着時刻
		@interval=[]    # メッセージの到着間隔(指数分布burstでのみ利用)
		@count=[]       # メッセージの到着件数(ポアソン分布burstでのみ利用)
		@dist=dist      # 分布オブジェクト(PoissonBurst, ExpBurst, GaussBurst, BinomBurst)
		@stateSize = @dist.initProbLn().size # 状態数
		@dataSize  = @dist.data.size # 状態数
	end

  # ###############################
  # 二次元配列の確保
	def array2dim(rowSize,colSize)
		array=Array.new(rowSize)
		(0...rowSize).each{|i|
			array[i] = Array.new(colSize)
		}
		return array
	end

	# ###############################
	# 全stateからtargetStateへの尤度を計算し、最大尤度と最大尤度を達成するfrom state番号を返す。
	def getMaxLike(targetState,prevLike,trans,prob)
		maxLike=-99999999.0
		maxFrom=nil
		(0...@stateSize).each{|from|
#puts "from=#{from} prevLike[from]=#{prevLike[from]} trans[from][targetState]=#{trans[from][targetState]} prob[targetState]=#{prob[targetState]}"
			# 時刻t-1における尤度+log(遷移確率)+log(状態確率)
			like=prevLike[from]+trans[from][targetState]+prob[targetState]
			if maxLike<like
				maxLike=like
				maxFrom=from
			end
		}
#puts "maxLike=#{maxLike} maxFrom=#{maxFrom}"
		return maxLike,maxFrom
	end

	# ###############################
	# viterbi forwardアルゴリズム
	# initProbLn : 初期状態確率
	# stateProbLn: 状態確率
	# transProbLn: 状態遷移確率
	def viterbi_fwd(initProbLn, stateProbLn, transProbLn)

		# 各stateでの最小コストtransitionの計算実行
		like =array2dim(@dataSize+1,@stateSize)
		from =array2dim(@dataSize  ,@stateSize)

		# 初期状態セット
		(0...@stateSize).each{|state|
			like[0][state]=initProbLn[state]
		}

		# 初期状態が0なので1から始まる
		(1..@dataSize).each{|t|
			(0...@stateSize).each{|state|
				#              tは1から始まるのでfromと@stateProbLnはt-1となる: likeのみ0要素を持つ
				like[t][state],from[t-1][state] = getMaxLike( state, like[t-1], @transProbLn, @stateProbLn[t-1])
			}
		}
		return like,from
	end

	def getMaxState(like)
		maxLike=-99999999.0
		maxState=nil
		(0...@stateSize).each{|state|
			if maxLike<like[state]
				maxLike=like[state]
				maxState=state
			end
		}
		maxState
	end

	# ###############################
	# viterbi backwordアルゴリズム
	def viterbi_bwd(like,from)
		state=Array.new(@dataSize)

		# 最終時刻における尤度最大のstate
		state[@dataSize-1]=getMaxState(like.last)
		(@dataSize-1).step(1,-1){|t|
			state[t-1]=from[t][state[t]]
		}
		return state
	end

public

	def detect(inertiaProb,burstScale)
		@burstScale  = burstScale              # burst状態のパラメータのスケールリング
		@inertiaProb = inertiaProb             # 同じ状態への遷移確率

		# 初期状態ベクトル(状態数)の取得
		@initProbLn=@dist.initProbLn()

		# 状態確率行列(データ数×状態数)の取得
		@stateProbLn=@dist.stateProbLn(@burstScale)

		# 状態遷移行列(状態数×状態数)の取得
		@transProbLn=@dist.calTransProbLn(@inertiaProb)

		# viterbiアルゴリズムforward実行
		@lLikely,@from=viterbi_fwd(@initProbLn,@stateProbLn,@transProbLn)

		# viterbiアルゴリズムbackward実行
		@state=viterbi_bwd(@lLikely,@from)
	end

	# CSVによる出力
	# 入力データの末尾にburst項目を追加して出力
	def output(iFile,oFile)
		MCMD::Mcsvin.new("i=#{iFile} -array"){|iCsv|
			File.open(oFile,"w"){|fpw|
				fpw.puts "#{iCsv.names.join(',')},burst"
				i=0
				iCsv.each{|flds|
					fpw.puts "#{flds.join(',')},#{@dist.burstSymbol[@state[i]]}"
					i+=1
				}
			}
		}
	end

	# debug出力
	def show(fpw=STDERR)
		fpw.puts "### MDM::Burst class"
		fpw.puts "  @burstScale: #{@burstScale}"
		fpw.puts "  log(初期状態確率):"
		(0...@stateSize).each{|i|
			fpw.puts "    @initProbLn[#{i}]: #{@initProbLn[i]}"
		}
		fpw.puts "  log(状態遷移確率): @inertiaProb: #{@inertiaProb}"
		(0...@stateSize).each{|i|
			(0...@stateSize).each{|j|
				fpw.puts "    @transProbLn[#{i}][#{j}]: #{@transProbLn[i][j]}"
				@transProbLn
			}
		}

		# 項目名表示
		fpw.print ""
		fpw.print "   t\t"
		fpw.print "  val\t"
		(0...@stateSize).each{|state| fpw.print "probLn#{state}\t"}
		(0...@stateSize).each{|state| fpw.print "likeLn#{state}\t"}
		(0...@stateSize).each{|state| fpw.print "  from#{state}\t"}
		fpw.print "  state\t"
		fpw.puts ""

		# 初期尤度表示
		(0...@stateSize+2).each{|i| fpw.print "\t"}
		(0...@stateSize).each{|state| fpw.print sprintf("%7.1f\t",@lLikely[0][state])}
		fpw.puts ""

		# 期別尤度表示
		(0...@dataSize).each{|i|
			data =@dist.data[i]
			stateProbLN=@stateProbLn[i]
			lLikely=@lLikely[i+1]
			from=@from[i]

			fpw.print sprintf("%4d\t",i)
			fpw.print sprintf("%7.3f\t",data)
			(0...@stateSize).each{|state| fpw.print sprintf("%7.3f\t",stateProbLN[state])}
			(0...@stateSize).each{|state| fpw.print sprintf("%7.3f\t",lLikely[state])}
			(0...@stateSize).each{|state| fpw.print sprintf("%7d\t",from[state])}
			fpw.print sprintf("%7s\t",@dist.burstSymbol[@state[i]])
			fpw.print "\n"
		}
	end

end # class end

########################## Module end
end

if distType=="exp"
	dist=MDM::ExpBurst.new(iFile, fName, pName, param)
elsif distType=="poisson"
	dist=MDM::PoissonBurst.new(iFile, fName, pName, param)
elsif distType=="gauss"
	dist=MDM::GaussBurst.new(iFile, fName, pName, param, vName, var)
elsif distType=="binom"
	dist=MDM::BinomBurst.new(iFile, fName, pName, param, nName, trial)
end

burst=MDM::Burst.new(dist)
burst.detect(iProb, burstScale)
burst.output(iFile,oFile)
if dFile
	File.open(dFile,"w"){|fpw|
		dist.show(fpw)
		burst.show(fpw)
	}
end

