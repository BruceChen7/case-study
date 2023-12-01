// since there's no dynamic data here, we can prerender
// it so that it gets served as a static asset in production
// export const prerender = true;

import type { PageLoad } from './$types';
export const load: PageLoad = async ({ fetch, _ }) => {
    const res = await fetch("http://127.0.0.1:8080");
    const todoList = await res.json();
    return {
        todoList
    }
}
