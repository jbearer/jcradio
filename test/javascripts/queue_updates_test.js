const assert = require('assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const source = fs.readFileSync(path.join(__dirname, '../../app/assets/javascripts/queue.js.erb'), 'utf8');

function browser(options = {}) {
    const requests = [];
    const notifications = [];
    const handlers = {};
    const timers = [];
    const clearedTimers = [];
    let ready;
    let reloads = 0;
    let queueHtml = '';
    let nextUp = '';
    const queue = {
        length: options.onQueue === false ? 0 : 1,
        attr: () => '1',
        html: content => { queueHtml = content; }
    };
    const context = {
        document: { hidden: !!options.hidden, hasFocus: () => options.focused !== false },
        window: {
            location: { pathname: options.pathname || '/stations/1' },
            setInterval: (callback, delay) => timers.push({ callback, delay }),
            clearInterval: timer => clearedTimers.push(timer)
        },
        location: { reload: () => { reloads += 1; } },
        logged_in: () => options.loggedIn !== false,
        current_user: () => ({ id: 1 }),
        push: (...args) => notifications.push(args),
        $: selector => {
            if (typeof selector === 'function') { ready = selector; return; }
            if (selector === '#station-queue') return queue;
            if (selector === '#next-up') return { text: content => { nextUp = content; } };
            return {
                off(event) { delete handlers[event]; return this; },
                on(event, callback) { handlers[event] = callback; return this; }
            };
        }
    };
    context.$.ajax = settings => {
        const request = {
            settings,
            done(callback) { this.success = callback; return this; },
            always(callback) { this.complete = callback; return this; },
            resolve(state) { this.success(state); this.complete(); },
            reject() { this.complete(); }
        };
        requests.push(request);
        return request;
    };
    vm.createContext(context);
    vm.runInContext(source, context);
    return {
        context, requests, notifications, handlers, timers, clearedTimers,
        ready: () => ready(),
        reloadScript: () => vm.runInContext(source, context),
        get reloads() { return reloads; },
        get queueHtml() { return queueHtml; },
        get nextUp() { return nextUp; }
    };
}

const listener = { id: 1, username: 'Austin' };
const other = { id: 2, username: 'Other listener' };
const snapshot = { queue_html: '<table>Buddy song</table>', next_user: listener, next_letter: 'K' };

const quiet = browser();
quiet.context.next_up(listener, 'K', false);
assert.strictEqual(quiet.requests.length, 1);
quiet.requests[0].resolve(snapshot);
assert.strictEqual(quiet.queueHtml, snapshot.queue_html);
assert.strictEqual(quiet.nextUp, "Next up... Austin with 'K'");
assert.strictEqual(quiet.notifications.length, 0);
assert.strictEqual(quiet.reloads, 0);

const focused = browser();
focused.context.next_up(listener, 'K', true);
assert.strictEqual(focused.notifications.length, 0);
assert.strictEqual(focused.requests.length, 1);

const hidden = browser({ hidden: true });
hidden.context.next_up(listener, 'K', true);
assert.strictEqual(hidden.requests.length, 0);
assert.deepStrictEqual(hidden.notifications, [["It's your turn! Your letter is: K", '/stations/1']]);
hidden.context.next_up(other, 'S', true);
assert.strictEqual(hidden.notifications.length, 1);

const unfocused = browser({ focused: false });
unfocused.context.next_up(listener, 'K');
assert.strictEqual(unfocused.notifications.length, 1);

const elsewhere = browser({ onQueue: false, pathname: '/chat' });
elsewhere.ready();
elsewhere.timers[0].callback();
elsewhere.context.next_up(listener, 'K', true);
assert.strictEqual(elsewhere.requests.length, 0);
assert.strictEqual(elsewhere.notifications.length, 1);
assert.strictEqual(elsewhere.reloads, 0);

const search = browser({ onQueue: false, pathname: '/songs/search' });
search.context.next_up(listener, 'K', false);
assert.strictEqual(search.reloads, 1);
assert.strictEqual(search.notifications.length, 0);

const polling = browser();
polling.ready();
assert.strictEqual(polling.requests.length, 1);
assert.strictEqual(polling.requests[0].settings.url, '/stations/1.json');
assert.strictEqual(polling.requests[0].settings.timeout, 10000);
assert.strictEqual(polling.timers[0].delay, 3000);
polling.context.next_up(other, 'S', false);
assert.strictEqual(polling.requests.length, 1);
polling.requests[0].resolve(snapshot);
assert.strictEqual(polling.requests.length, 2);
polling.requests[1].reject();
polling.timers[0].callback();
assert.strictEqual(polling.requests.length, 3);
polling.requests[2].resolve(snapshot);
polling.context.document.hidden = true;
polling.timers[0].callback();
assert.strictEqual(polling.requests.length, 3);
polling.context.document.hidden = false;
polling.handlers['visibilitychange.queue']();
assert.strictEqual(polling.requests.length, 4);
polling.requests[3].resolve(snapshot);
polling.handlers['focus.queue']();
assert.strictEqual(polling.requests.length, 5);
assert.strictEqual(polling.notifications.length, 0);
assert.strictEqual(polling.reloads, 0);

const anonymous = browser({ loggedIn: false });
anonymous.context.next_up(listener, 'K', true);
assert.strictEqual(anonymous.requests.length, 1);
assert.strictEqual(anonymous.notifications.length, 0);

const navigation = browser();
navigation.ready();
navigation.requests[0].resolve(snapshot);
navigation.reloadScript();
navigation.ready();
assert.deepStrictEqual(navigation.clearedTimers, [1]);
assert.strictEqual(navigation.timers.length, 2);
assert.strictEqual(Object.keys(navigation.handlers).length, 2);

console.log('Queue updates: polling, event refresh, retry, focus, and turn notification checks passed');
