var ringowikiapi = {};
ringowikiapi.create_form_data = function (selector) {
  var form = $(selector);
  var params = {};
  form.find('input').each(function () {
    var type = $(this).attr("type") || '';
    if (type === '' || type === 'password' || type === 'hidden') {
      var name = $(this).attr('name');
      params[name] = $(this).val();
    }
  });
  
  form.find('textarea').each(function () {
    var name = $(this).attr('name');
    params[name] = $(this).val();
  });
  
  return params;
};
