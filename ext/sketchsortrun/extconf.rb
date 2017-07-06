require "rubygems"
require "mkmf"

unless have_library("boost_system")
  puts("need boost_system.")
  exit 1
end

unless have_library("kgmod3")
  puts("need libkgmod.")
  puts("refer https://github.com/nysol/mcmd")
  exit 1
end



cp = "$(srcdir)"

$CFLAGS = " -O3 -DNDEBUG -D_NO_MAIN_ -Wno-deprecated -pedantic -ansi -finline-functions -foptimize-sibling-calls -Wcast-qual -Wwrite-strings -Wsign-promo -Wcast-align -Wno-long-long -fexpensive-optimizations -funroll-all-loops -ffast-math -fomit-frame-pointer -pipe -I./"
$CPPFLAGS = " -O3 -DNDEBUG -D_NO_MAIN_ -Wno-deprecated -pedantic -ansi -finline-functions -foptimize-sibling-calls -Wcast-qual -Wwrite-strings -Wsign-promo -Wcast-align -Wno-long-long -fexpensive-optimizations -funroll-all-loops -ffast-math -fomit-frame-pointer -pipe -I./"
$CXXFLAGS = " -O3 -stdlib=libstdc++ -DNDEBUG -D_NO_MAIN_ -Wno-deprecated -pedantic -ansi -finline-functions -foptimize-sibling-calls -Wcast-qual -Wwrite-strings -Wsign-promo -Wcast-align -Wno-long-long -fexpensive-optimizations -funroll-all-loops -ffast-math -fomit-frame-pointer -pipe -I./"

$LOCAL_LIBS += " -lstdc++ -lkgmod3 -lm -lboost_system"

create_makefile("nysol/sketchsortrun")

