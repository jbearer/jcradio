const assert = require('assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const partial = fs.readFileSync(
  path.join(__dirname, '../../app/views/songs/_search_results.html.erb'), 'utf8'
);
const script = partial.slice(partial.indexOf('function confirmSong('), partial.lastIndexOf('</script>'))
  .replace('<%= @station.next_letter %>', 'L');
const now = Date.parse('2026-09-14T00:00:00Z');
const twoDays = 1000 * 60 * 60 * 24 * 2;
let dialog;
const context = {
  Date: class extends Date {
    static now() { return now; }
  },
  $: () => ({
    prepend: content => { dialog = content; },
    click: () => {}
  })
};
vm.createContext(context);
vm.runInContext(script, context);

function checkWarning(lastPlayed, expected, description) {
  context.confirmSong(0, {
    title: 'Love Interruption', artist: 'Jack White', first_letter: 'L',
    next_letter: 'I', last_played: lastPlayed
  });
  assert.strictEqual(dialog.includes('Warning: Song has been chosen'), expected, description);
  assert(dialog.includes('Add "Love Interruption" by Jack White to queue?'));
  assert(dialog.includes('doAction'));
  assert(dialog.includes('cancelAction'));
}

checkWarning(now - 10 * 60 * 1000, true, 'recent epoch-millisecond timestamp warns');
checkWarning(now, true, 'just queued song warns');
checkWarning(now - twoDays + 1, true, 'just inside two days warns');
checkWarning(now - twoDays, false, 'exactly two days does not warn');
checkWarning(now - twoDays - 1, false, 'old song does not warn');
checkWarning(null, false, 'unplayed song does not warn');
checkWarning(undefined, false, 'missing timestamp does not warn');
checkWarning('invalid', false, 'invalid timestamp does not warn');
console.log('Recent-song dialog: 8 cases passed');
