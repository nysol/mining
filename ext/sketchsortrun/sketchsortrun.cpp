#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <string>
#include <ruby.h>

#include "Main.hpp"


#include <kgMethod.h>

extern "C" {
	void Init_sketchsortrun(void);
}


VALUE sketchsort(VALUE self,VALUE argvV){

	string argstr=RSTRING_PTR(argvV);
	vector<char *> opts = kglib::splitToken(const_cast<char*>(argstr.c_str()), ' ',true);

	// 引数文字列へのポインタの領域はここでauto変数に確保する
	kglib::kgAutoPtr2<char*> argv;
	char** vv;
	try{
		argv.set(new char*[opts.size()+1]);
		vv = argv.get();
	}catch(...){
		rb_raise(rb_eRuntimeError,"memory allocation error");
	}

	// vv配列0番目はコマンド名
	vv[0]=const_cast<char*>("lcm");

	size_t vvSize;
	for(vvSize=0; vvSize<opts.size(); vvSize++){
		vv[vvSize+1] = opts.at(vvSize);
	}
	vvSize+=1;
	int rtn = sketchsort_main (vvSize,vv);
	return INT2NUM(rtn);
}

// -----------------------------------------------------------------------------
// ruby Mcsvin クラス init
// -----------------------------------------------------------------------------
void Init_sketchsortrun(void) 
{
	// モジュール定義:MCMD::xxxxの部分
	VALUE mtake=rb_define_module("NYSOL_MINING");
	rb_define_module_function(mtake,"run_sketchsort"       , (VALUE (*)(...))sketchsort,1);
}


