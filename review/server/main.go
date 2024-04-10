package main

import "net/http"

func main() {
	// 建立一个 http servr，监听 8080 端口
	// 并处理http请求
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		// return json data
		// {
		// "data": [
		//                 "to write program"
		// ]
		// }
		json := `{"data": ["to write program"]}`
		// set http header
		w.Header().Set("Content-Type", "application/json")
		// Access-Control-Allow-Origin
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Write([]byte(json))
	})

	http.ListenAndServe(":8080", nil)

}
