var ringowikiapi = {};
ringowikiapi.create_form_data = function (selector) {
  var form = $(selector);
  var params = {};
  form.find('input').each(function () {
    var type = $(this).type || '';
    var name = $(this).attr('name');
    if (type === '' || type === 'password') {
      params[name] = $(this).val();
    }
  });
  return params;
};
