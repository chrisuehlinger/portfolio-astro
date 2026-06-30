(function ($) {
  function escapeHtml(value) {
    return String(value || '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  function renderMarkdownPreview(markdown) {
    var html = escapeHtml(markdown);
    html = html.replace(/^### (.*)$/gm, '<h3>$1</h3>');
    html = html.replace(/^## (.*)$/gm, '<h2>$1</h2>');
    html = html.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>');
    html = html.replace(/\*(.*?)\*/g, '<em>$1</em>');
    html = html.replace(/\[([^\]]+)\]\((https?:\/\/[^)]+)\)/g, '<a href="$2" target="_blank" rel="noopener noreferrer">$1</a>');
    return html
      .split(/\n{2,}/)
      .map(function (block) {
        if (/^<h[23]>/.test(block)) return block;
        return '<p>' + block.replace(/\n/g, '<br>') + '</p>';
      })
      .join('');
  }

  function chooseAttachment(targetInput) {
    var frame = wp.media({
      title: 'Choose media',
      button: { text: 'Use media' },
      multiple: false,
    });

    frame.on('select', function () {
      var attachment = frame.state().get('selection').first().toJSON();
      $('#' + targetInput).val(attachment.id).trigger('change');
    });

    frame.open();
  }

  $(document).on('click', '.portfolio-pick-attachment', function () {
    chooseAttachment($(this).data('target'));
  });

  $(document).on('click', '.portfolio-preview-button', function () {
    var source = $('#' + $(this).data('source')).val();
    $('#' + $(this).data('target')).html(renderMarkdownPreview(source));
  });

  function readMediaItems() {
    try {
      var items = JSON.parse($('#portfolio_media_json').val() || '[]');
      return Array.isArray(items) ? items : [];
    } catch (error) {
      return [];
    }
  }

  function writeMediaItems(items) {
    $('#portfolio_media_json').val(JSON.stringify(items));
  }

  function renderMediaRows() {
    var $list = $('#portfolio-media-list');
    if (!$list.length) return;

    var items = readMediaItems();
    $list.empty();

    items.forEach(function (item, index) {
      var row = [
        '<div class="portfolio-media-row" data-index="' + index + '">',
        '<label>Type<select data-field="type">',
        '<option value="image">Image</option>',
        '<option value="video">Video</option>',
        '<option value="embed">Embed</option>',
        '</select></label>',
        '<label>Attachment ID<input type="number" data-field="attachmentId"></label>',
        '<button type="button" class="button portfolio-row-pick" data-field="attachmentId">Choose attachment</button>',
        '<label>Poster ID<input type="number" data-field="posterId"></label>',
        '<button type="button" class="button portfolio-row-pick" data-field="posterId">Choose poster</button>',
        '<label>Provider<select data-field="provider"><option value="youtube">YouTube</option><option value="vimeo">Vimeo</option></select></label>',
        '<label>Embed URL<input type="url" data-field="url"></label>',
        '<label>Title<input type="text" data-field="title"></label>',
        '<label>Caption<textarea data-field="caption" rows="2"></textarea></label>',
        '<div class="portfolio-media-row-actions">',
        '<button type="button" class="button portfolio-row-up">Up</button>',
        '<button type="button" class="button portfolio-row-down">Down</button>',
        '<button type="button" class="button portfolio-row-remove">Remove</button>',
        '</div>',
        '</div>',
      ].join('');

      var $row = $(row);
      $row.find('[data-field="type"]').val(item.type || 'image');
      $row.find('[data-field="attachmentId"]').val(item.attachmentId || '');
      $row.find('[data-field="posterId"]').val(item.posterId || '');
      $row.find('[data-field="provider"]').val(item.provider || 'youtube');
      $row.find('[data-field="url"]').val(item.url || '');
      $row.find('[data-field="title"]').val(item.title || '');
      $row.find('[data-field="caption"]').val(item.caption || '');
      $list.append($row);
    });
  }

  $(document).on('change input', '.portfolio-media-row [data-field]', function () {
    var items = readMediaItems();
    var $row = $(this).closest('.portfolio-media-row');
    var index = Number($row.data('index'));
    var field = $(this).data('field');
    items[index] = items[index] || {};
    items[index][field] = $(this).val();
    writeMediaItems(items);
  });

  $(document).on('click', '#portfolio-add-media', function () {
    var items = readMediaItems();
    items.push({ type: 'image' });
    writeMediaItems(items);
    renderMediaRows();
  });

  $(document).on('click', '.portfolio-row-remove', function () {
    var items = readMediaItems();
    items.splice(Number($(this).closest('.portfolio-media-row').data('index')), 1);
    writeMediaItems(items);
    renderMediaRows();
  });

  $(document).on('click', '.portfolio-row-up, .portfolio-row-down', function () {
    var items = readMediaItems();
    var index = Number($(this).closest('.portfolio-media-row').data('index'));
    var direction = $(this).hasClass('portfolio-row-up') ? -1 : 1;
    var next = index + direction;
    if (next < 0 || next >= items.length) return;
    var temp = items[index];
    items[index] = items[next];
    items[next] = temp;
    writeMediaItems(items);
    renderMediaRows();
  });

  $(document).on('click', '.portfolio-row-pick', function () {
    var $row = $(this).closest('.portfolio-media-row');
    var field = $(this).data('field');
    var frame = wp.media({
      title: 'Choose media',
      button: { text: 'Use media' },
      multiple: false,
    });

    frame.on('select', function () {
      var attachment = frame.state().get('selection').first().toJSON();
      $row.find('[data-field="' + field + '"]').val(attachment.id).trigger('input');
    });

    frame.open();
  });

  $(renderMediaRows);
})(jQuery);
