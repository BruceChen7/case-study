## 说明
* 使用.gopcintab用例进行栈帧展开
    * [go-profiler-notes/stack-traces.md](https://github.com/DataDog/go-profiler-notes/blob/main/stack-traces.md#gopclntab)
* go提供了两种gopcintab的实现
    * debug/gosym package，被链接器、 go tool addr2line 和其他程序使用
    * [go/src/runtime/symtab.go at go1.16.3 ](https://github.com/golang/go/blob/go1.16.3/src/runtime/symtab.go)
* 运行
    * ./pcinttab ./pcinttab
    * 自己查看自己的调用栈

