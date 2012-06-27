(function($){
    $(function(){
        var updateMultipostCategoryId = function() {
            var blog_id = $('select#multipost_blog_id').val();
            var new_val = '';
            if(blog_id > 0) {
                new_val = $('#multipost-category-selector-' + blog_id).find('select').val();
            }
            $('input#multipost_category_id').val( new_val );
        };
        $('.multipost-category-selector').find('select').change( function(){ updateMultipostCategoryId(); } );
        var toggleMultipostCategorySelector = function() {
            var blog_id = $('select#multipost_blog_id').val();
            var selectors = $('.multipost-category-selector');
            selectors.hide();
            if(blog_id > 0) {
                $('#multipost_category_id-field').show();
                $('#multipost-category-selector-' + blog_id).show();
            } else {
                $('#multipost_category_id-field').hide();
            }
            updateMultipostCategoryId();
        }
        $('select#multipost_blog_id').change(function(){ toggleMultipostCategorySelector(); });

        var toggleMultipost = function(){
            if($('input#multipost:checked').val() == '1') {
                $('#multipost_blog_id-field').show();
                $('#multipost_category_id-field').show();
                toggleMultipostCategorySelector();
            } else {
                $('#multipost_blog_id-field').hide();
                $('#multipost_category_id-field').hide();
            }
        };
        toggleMultipost();
        $('input#multipost').click(function(){ toggleMultipost(); });

    });
})(jQuery);