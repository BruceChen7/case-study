<script>
    import "../app.css";
</script>

<!-- -- div在宽度居中 -->
<div class="container mx-auto w-6/12 border-b boder-gray-300 py-4">
    <ul class="flex space-x-8 width-3/4">
        <li>
            <a
                class="hover:text-sky-500 dark:hover:text-sky-400 hover:font-bold"
                href="">待办事项</a
            >
        </li>
        <li>
            <a href="" class="hover:text-sky-500 dark:hover:text-sky-400"
                >正在进行</a
            >
        </li>
        <li>
            <a
                class="hover:text-sky-500 dark:hover:text-sky-400 font-normal"
                href="">已经完成</a
            >
        </li>
        <li>
            <a class="hover:text-sky-500 dark:hover:text-sky-400" href=""
                >归档</a
            >
        </li>
    </ul>
</div>

<div class="container mx-auto w-6/12 py-4">
    <ul
        class="max-auto space-y-2 text-gray-700 list-disc list-inside dark:text-gray-400"
    >
        <li class="flex mb-2 list-disc marker:text-blue-200 justify-between">
            <p class="list-disc space-x-2 w-3/4">
                学会使用Svelte afaaafaf aaaaaaaaaaaaaaaaaaaaaaaaaaaa afafafaaaaa
                学会使用Svelte afaaafaf aaaaaaaaaaaaaaaaaaaaaaaaaaaa afafafaaaaa
                学会使用Svelte afaaafaf aaaaaaaaaaaaaaaaaaaaaaaaaaaa afafafaaaaa
            </p>
            <button
                type="button"
                class="h-3/4 text-white justify-end ml-2 px-2 bg-gray-700 hover:bg-blue-800 space-x-2 font-medium rounded-lg"
                >Add</button
            >
            <button
                type="button"
                class="h-3/4 text-white ml-2 justify-end px-2 space-x-2 bg-gray-700 hover:bg-blue-800 font-medium rounded-lg"
                >Doing</button
            >
        </li>
        <li class="flex mb-4 mr-0 justify-between">
            <p class="w-3/4">
                学会使用Svelte afaaafaf aaaaaaaaaaaaaaaaaaaaaaaaaaaa afafafaaaaa
                afafaffa afaf
            </p>
            <button
                type="button"
                class="h-3/4 text-white ml-2 px-2 bg-gray-700 hover:bg-blue-800 focus:ring-4 focus:ring-blue-300 font-medium rounded-lg"
                >Add</button
            >
            <button
                type="button"
                class="h-3/4 text-white ml-2 px-2 bg-gray-700 hover:bg-blue-800 focus:ring-4 focus:ring-blue-300 font-medium rounded-lg"
                >Doing</button
            >
        </li>
    </ul>
</div>
