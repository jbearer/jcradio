// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or any plugin's vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file.
//
// Read Sprockets README (https://github.com/rails/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require jquery
//= require jquery_ujs
//= require turbolinks
//= require_tree .

function flash(msg, {type, dismissible, selector, timeout} = {}) {
  type = type || 'notify'
  dismissible = dismissible || true
  selector = selector || '#flash'
  timeout = timeout || 5000

  if (type == 'error') {
    type = 'danger'
  }

  error = $('<div>')
  error.addClass("alert alert-" + type)

  close = function(){error.fadeOut({complete: function() {error.remove()}})}

  if (dismissible) {
    error.addClass("alert-dismissible")
    close_button = $('<button type="button" class="close" data-dismiss="alert">&times;</button>')
    close_button.on("click", close)
    error.append(close_button)
  }
  error.append(msg)

  if (timeout >= 0) {
    setTimeout(close, timeout)
  }

  $(selector).append($(error))
}
