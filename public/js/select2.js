$(document).ready(function() {
    $('.js-example-basic-multiple').select2();
});

$(document).ready(function() {
    $('.js-example-basic-single').select2();
});
// $.fn.serializeObject = function() {
//     var o = {};
//     var a = this.serializeArray();
//     $.each(a, function() {
//         if (o[this.name]) {
//             if (!o[this.name].push) {
//                 o[this.name] = [o[this.name]];
//             }
//             o[this.name].push(this.value || '');
//         } else {
//             o[this.name] = this.value || '';
//         }
//     });
//     return o;
// };

// $(function() {
//     $('form.match').on('submit', function(e) {
//       e.preventDefault();

//       var formData = $(this).serializeObject();
//       console.log(formData);
//       $('.datahere').html(formData);
//     });
// });