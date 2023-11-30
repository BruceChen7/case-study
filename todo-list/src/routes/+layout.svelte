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

<section>
    <slot />
</section>
