<script>
</script>

<!--定义的是一个页面的header结构-->
<!-- 每个page都会有 -->
<svelte:head>
    <title>Home</title>
    <meta name="description" content="Svelte demo app" />
</svelte:head>

<section>
    <h1 class="text-15xl font-bold underline">Hello world!</h1>
    <h1>
        <span class="welcome">
            <picture> </picture>
        </span>

        to your new<br />SvelteKit app
    </h1>

    <h2 class="text-center">
        try editing <strong>src/routes/+page.svelte</strong>
    </h2>

    <p class="bg-red-500 text-3xl">Hello from page</p>
</section>

<style lang="postcss">
</style>
