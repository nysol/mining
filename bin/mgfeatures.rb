#!/usr/bin/env ruby
# encoding: utf-8

# 1.0 initial development: 2015/10/20
# 1.1 minor modifications: 2015/12/09
$version="1.1"
$revision="###VERSION###"
CMD="mgfeatures.rb"

def help

STDERR.puts <<EOF
----------------------------
#{CMD} version #{$version}
----------------------------
summary) calculation graph features by igraph
feature) output the following graph features
  node_size        : number of nodes
  edge_size        : number of edges
  degree0_node_size : number of nodes with 0 degree
  mean_degree      : mean of degree
  median_degree    : median of degree
  min_degree       : min of degree
  max_degree       : max of degree
  graph_density    : graph density
  transitivity     : so called clustering coefficient
  average_shortest_path    : mean of shortest path length for all pair of edges
  diameter         : max of shortest path length for all pair of edges

format) #{CMD} I=|(ei= [ni=]) ef= [nf=] O=|o= [log=] [T=] [--help]
args=MCMD::Margs.new(ARGV,"I=,ei=,ef=,ni=,nf=,o=,O=,diameter=,graph_density=,log=,-verbose","ef=,O=")
 I=     : path name of input files
         : file extention of edge file must be ".edge" in this path
         : file extention of node file must be ".node" in this path
  ei=    : input file name of edge (cannot be specified with I=)
  ef=    : field name of edge (two nodes)
  ni=    : input file name of nodes (cannot be specified with I=)
         : if omitted, only edge file is used
  nf=    : field name of node
  -directed : assume a directed graph
  O=     : output path

  ## parameter for each feature (see igraph manual in detail)
  diameter=unconnected=[TRUE|FALSE],directed=[TRUE|FALSE]
  graph_density=loops=[FALSE|TRUE]
  average_shortest_path=unconnected=[TRUE|FALSE],directed=[TRUE|FALSE]

  ## others
  mp=      : Number of processes for parallel processing
  T=       : working directory (default:/tmp)
  -mcmdenv : show the END messages of MCMD
  --help   : show help

required software)
  1) R
  2) igraph package for R

example)
$ cat data/dat1.edge
v1,v2
E,J
E,A
J,D
J,A
J,H
D,H
D,F
H,F
A,F
B,H
$ cat data/dat1.node
v
A
B
C
D
E
F
G
H
I
J
$ #{CMD} I=data O=data/result1 ef=v1,v2 nf=v O=result
#MSG# converting graph files into a pair of numbered nodes ...; 2015/10/20 14:57:26
#END# ../bin/mgfeatrues.rb I=./data O=result1 ef=v1,v2 nf=v; 2015/10/20 14:57:27
$ cat data/dat1.csv
id,node_size,edge_size,degree0_node_size,mean_degree,median_degree,min_degree,max_degree,graph_density,transitivity,average_shortest_path,diameter
dat1,10,10,3,2,2.5,0,4,0.222222222222222,0.409090909090909,1.61904761904762,3

# without specifying nf= (node file isn't used)
$ #{CMD} I=data O=data/result1 ef=v1,v2 O=result
#MSG# converting graph files into a pair of numbered nodes ...; 2015/10/20 14:57:26
#END# ../bin/mgfeatrues.rb I=./data O=result1 ef=v1,v2 nf=v; 2015/10/20 14:57:27
$ cat data/dat1.csv
id,node_size,edge_size,degree0_node_size,mean_degree,median_degree,min_degree,max_degree,graph_density,transitivity,average_shortest_path,diameter
dat1,10,10,0,2.85714285714286,3,1,4,0.476190476190476,0.409090909090909,1.61904761904762,3

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

# confirm if R library is installed
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
def g2pair(ni,nf,ei,ef1,ef2,numFile,mapFile)
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
	#f << "mfsort f=num1,num2 |"
	f << "msortf f=num1%n,num2%n -nfno | tr ',' ' ' >#{numFile}"
	system(f)

	nodeSize=MCMD::mrecount("i=#{mapFile}")

	return nodeSize
end

####
# generating the R script for graph features
# pars: parameters for each graph feature
def genRscript(directed,pars,eFile,nodeSize,oFile,scpFile)
	dir="FALSE"
	dir="TRUE"  if directed

	r_proc = <<EOF
library(igraph)
## reading edge file
g=read.graph("#{eFile}",format="edgelist",directed=#{dir},n=#{nodeSize})

####
deg=degree(g)
node_size=vcount(g)
edge_size=ecount(g)
mean_degree=mean(deg)
median_degree=median(deg)
min_degree=min(deg)
max_degree=max(deg)
degree0_node_size=length(deg[deg==0])
graph_density=graph.density(g #{pars["graph_density"]})
average_shortest_path=average.path.length(g #{pars["average_shortest_path"]})

#### diameter
diameter=diameter(g #{pars["diameter"]})
transitivity=transitivity(g)

dat=data.frame(
	node_size=node_size,
	edge_size=edge_size,
	degree0_node_size=degree0_node_size,
	mean_degree=mean_degree,
	median_degree=median_degree,
	min_degree=min_degree,
	max_degree=max_degree,
	graph_density=graph_density,
	transitivity=transitivity,
	average_shortest_path=average_shortest_path,
	diameter=diameter
)
write.csv(dat,file="#{oFile}",quote=FALSE,row.names=FALSE)
EOF

	File.open(scpFile,"w"){|fpw|
		fpw.write(r_proc)
	}
end


#################################################################################################
#### Entry point

args=MCMD::Margs.new(ARGV,"I=,ei=,ef=,ni=,nf=,o=,O=,-directed,diameter=,graph_density=,average_shortest_path,-verbose,mp=","ef=,O=")

# suppress the end message of MCMD
ENV["KG_VerboseLevel"]="2" unless args.bool("-verbose")

# work file path
if args.str("T=")!=nil then
	ENV["KG_TmpPath"] = args.str("T=").sub(/\/$/,"")
end

# setting variables for edge file(s) and its field name
iPath = args.file("I=","r")
oPath = args.file("O=","w")

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

# setting variables for node file(s) and its field name.
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
	ni = args. file("ni=","r") # node file name
	if ni
		nf = args.field("nf=", ni)
		unless nf
			raise "#ERROR# nf= is mandatory, when ni= is specified"
		end
		nf=nf["names"][0]
	end
end

directed=args.bool("-directed")
MP=args.int("mp=",4)

pars={}
par=args.str("diameter=")
pars["diameter"]=",#{par}" if par
par=args.str("graph_density=")
pars["graph_density"]=",#{par}" if par
par=args.str("average_shortest_path")
pars["average_shortest_path"]=",#{par}" if par


MCMD::mkDir(oPath)


edgeFiles.meach(MP){|edgeFile|
	#MCMD::msgLog("START fearture extraction: #{edgeFile}")

	baseName=edgeFile.sub(/\.edge$/,"")
	name=baseName.sub(/^.*\//,"")

	nodeFile=edgeFile.sub(/\.edge$/,".node")

	# convert the original graph to one igraph can handle
	wf=MCMD::Mtemp.new
	xxnum=wf.file
	xxmap=wf.file
	xxout=wf.file
	xxscp=wf.file
	nodeSize=g2pair(nodeFile,nf,edgeFile,ef1,ef2,xxnum,xxmap)


	# generate R script, and run
	genRscript(directed,pars,xxnum, nodeSize, xxout, xxscp)
  if args.bool("-verbose") then
    system "R --vanilla -q < #{xxscp}"
  else
    system "R --vanilla -q --slave < #{xxscp} 2>/dev/null "
  end




	# store the result
	system "msetstr v=#{name} a=id i=#{xxout} | mcut -x f=0L,0-1L o=#{oPath}/#{name}.csv"
}

# end message
MCMD::endLog(args.cmdline)

