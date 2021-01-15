function basename(uri)
{
    segments = uri.split(/[/\\]/);
    return segments[segments.length - 1];
}

function default_emoji_name(uri)
{
    return basename(uri).split('\.')[0];
}

function set_emoji_name_placeholder(uri)
{
    name = default_emoji_name(uri);
    if (name === "") {
        $("#emoji_name").attr("placeholder", "Name...");
    } else {
        $("#emoji_name").attr("placeholder", name);
        $("#emoji_default_name").val(name);
    }
}

function drop_file(uri)
{
    set_emoji_name_placeholder(uri);
    $("#emoji_file_label").html(basename(uri));
}

$(() => {
    $("#emoji_file").change(() => {
        drop_file($("#emoji_file")[0].files[0].name);
    });

    $("#upload_form").on("dragover", function() {
        $("#upload_form").addClass("dragging");
        event.preventDefault();
        event.stopPropagation();
    }).on("dragleave", function() {
        $("#upload_form").removeClass("dragging");
        event.preventDefault();
        event.stopPropagation();
    }).on("drop", function(event) {
        $("#upload_form").removeClass("dragging");
        event.preventDefault();
        event.stopPropagation();

        url = event.originalEvent.dataTransfer.getData('URL');
        if (!url) {
            // If the user dropped a regular file, do the default action of adding it to the file
            // input.
            $("#emoji_file")[0].files = event.originalEvent.dataTransfer.files;
            drop_file($("#emoji_file")[0].files[0].name);
            return;
        }

        // Otherwise, we have special handling for URLs.
        drop_file(url);
        $("#emoji_url").val(url);
    });
});
