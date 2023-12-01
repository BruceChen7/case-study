<script lang="ts">
    import type { PageData } from "./$types";
    export let data: PageData;

    function handleKeydown(event: KeyboardEvent) {
        if (event.ctrlKey && event.key === "k") {
            event.preventDefault();
            console.log("input element");
            // return input html element
        }
    }
</script>

<!--定义的是一个页面的header结构-->
<!-- 每个page都会有 -->
<svelte:head>
    <title>Home</title>
    <meta name="description" content="Svelte demo app" />
</svelte:head>

<svelte:window on:keydown={handleKeydown} />

<div class="container mx-auto w-6/12 py-4">
    <ul
        class="max-auto space-y-2 text-gray-700 list-disc list-inside dark:text-gray-400"
    >
        {#each data.todoList.data as row}
            <li
                class="flex mb-2 list-disc marker:text-blue-200 justify-between"
            >
                <p class="list-disc space-x-2 w-3/4">
                    {row}
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
        {/each}
    </ul>
</div>

<style lang="postcss">
</style>
