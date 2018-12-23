#!/usr/bin/env ruby
# encoding: utf-8
require "rubygems"

spec = Gem::Specification.new do |s|
  s.name="nysol-mining"
  s.version="3.0.1"
  s.author="NYSOL"
  s.email="info@nysol.jp"
  s.homepage="http://www.nysol.jp/"
  s.summary="nysol mining tools"
	s.extensions = [
		'ext/sketchsortrun/extconf.rb'
	]
	s.files=Dir.glob([
		"ext/sketchsortrun/extconf.rb",
		"ext/sketchsortrun/extconf.rb",
		"ext/sketchsortrun/Main.cpp",
		"ext/sketchsortrun/Main.hpp",
		"ext/sketchsortrun/SketchSort.cpp",
		"ext/sketchsortrun/SketchSort.hpp",
		"ext/sketchsortrun/sketchsortrun.cpp",
		"lib/nysol/mining.rb",
		"bin/mnb.rb",
		"bin/mbopt.rb",
		"bin/mburst.rb",
		"bin/mgpmetis.rb",
		"bin/mnetsimile.rb",
		"bin/mgfeatures.rb",
		"bin/msketchsort.rb",
		"bin/mnewman.rb",
		"bin/mgnfeatures.rb",
		"bin/msm.rb",
		"bin/mglmnet.rb",
		"bin/m2glmnet.rb",
		"bin/midxmine.rb"
	])


	s.bindir = 'bin'
	s.executables = [
		"mburst.rb",
		"mgpmetis.rb",
		"mnb.rb",
		"mbopt.rb",
		"mnetsimile.rb",
		"mgfeatures.rb",
		"msketchsort.rb",
		"mnewman.rb",
		"mgnfeatures.rb",
		"mglmnet.rb",
		"m2glmnet.rb",
		"msm.rb",
		"midxmine.rb"
	]
	s.require_path = "lib"
	s.add_dependency "nysol" ,"~> 3.0.0"
	s.description = <<-EOF
    nysol Mining tools
	EOF

end
