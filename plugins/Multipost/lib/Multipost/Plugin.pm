package Multipost::Plugin;

use strict;

use File::Spec;
use File::Basename;

our $plugin = MT->component( 'Multipost' );

sub _cb_ts_edit_entry {
    my ( $cb, $app, $ref_str ) = @_;
    return unless $app->param( '_type' ) eq 'entry';
    my $tmpl_str = <<'TMPL';
<mt:setvarblock name="js_include" append="1">
<script src="<$MTStaticWebPath$>plugins/Multipost/jquery-1.7.2.min.js" type="text/javascript"></script>
<script type="text/javascript">jQuery.noConflict();</script>
<script src="<$MTStaticWebPath$>plugins/Multipost/util.js" type="text/javascript"></script>
</mt:setvarblock>
TMPL
    $$ref_str = $tmpl_str . $$ref_str;
    1;
}

sub _cb_tp_edit_entry {
    my ( $cb, $app, $param, $tmpl ) = @_;

    my $blog = $app->blog;
    my $user = $app->user;

    return unless defined( $user );
    return unless defined( $blog );
    return unless $app->param( '_type' ) eq 'entry';

    my $pointer = $tmpl->getElementById( 'entry-publishing-widget' );
    my $widget = $tmpl->createElement(
        'app:widget',
        {
            id => 'multipost-widget',
            label => $plugin->translate( 'Entry Copies' ),
        });

    my @blogs = ();
    my $blog_iter = MT->model( 'blog' )->load_iter(
        { id => { 'not' => $blog->id } }
    );
    while ( my $b = $blog_iter->() ) {
        next unless _can_on_blog( $user, $b, 'create_post' );
        push @blogs, $b;
    }
    return unless scalar( @blogs ) > 0;

    $param->{ multipost } = $app->param( 'multipost' );
    $param->{ multipost_blog_id } = $app->param( 'multipost_blog_id' );
    $param->{ multipost_category_id } = $app->param( 'multipost_category_id' );

    my $blog_select_options = "<option value=''>@{[ $plugin->translate( 'Please select' ) ]}</option>";
    my $category_selectors = '';
    foreach my $blog ( @blogs ) {
        $blog_select_options .= <<HTML;
<option value="@{[ $blog->id ]}" <mt:If name="multipost_blog_id" eq="@{[ $blog->id ]}">selected="selected"</mt:If>>@{[ $blog->name ]}</option>
HTML
        my @categories = ();
        my @root_categories = MT->model( 'category' )->top_level_categories( $blog->id );
        foreach my $root ( @root_categories ) {
            _trace_category( \@categories, $root );
        }

        my $category_selector = '<select>';
        $category_selector .= "<option value=''>@{[ $plugin->translate( 'Please select' ) ]}</option>";
        foreach my $category ( @categories ) {
            $category_selector .= <<HTML;
<option value="@{[ $category->{ id } ]}" <mt:If name="multipost_category_id" eq="@{[ $category->{ id }]}">selected="selected"</mt:If>>@{[ $category->{ label } ]}</option>
HTML
        }
        $category_selector .= '</select>';
        $category_selectors .= <<HTML;
<div id="multipost-category-selector-@{[ $blog->id ]}" class="multipost-category-selector">
$category_selector
</div>
HTML
    }

    my $html = <<HTML;
<mtapp:setting
  id="multipost"
  label_class="top-label"
  show_hint="0">

    <p>
    <mt:If name="multipost">
    <input type="checkbox" name="multipost" id="multipost" value="1" checked="checked">
    <mt:Else>
    <input type="checkbox" name="multipost" id="multipost" value="1">
    </mt:If>
    <label for="multipost">@{[ $plugin->translate( 'Copy to other blog.' ) ]}</label>
    </p>

</mtapp:setting>
<mtapp:setting
  id="multipost_blog_id"
  label="@{[ $plugin->translate( 'Blog' ) ]}"
  show_hint="0">

    <p>
      <select id="multipost_blog_id" name="multipost_blog_id">
      @{[ $blog_select_options ]}
      </select>
    </p>

</mtapp:setting>
<mtapp:setting
  id="multipost_category_id"
  label="@{[ $plugin->translate( 'Category' ) ]}"
  show_hint="0">

  <input type="hidden" id="multipost_category_id" name="multipost_category_id" />
  @{[ $category_selectors ]}

</mtapp:setting>
HTML

    $widget->innerHTML( $html );
    $tmpl->insertAfter( $widget, $pointer );

    

    1;
}

sub _trace_category {
    my ($ref_categories, $parent, $ref_chains) = @_;

    $ref_chains ||= [];

    push(@$ref_chains, $parent->label);
    my $category = {
        id => $parent->id,
        label => join(' > ', @$ref_chains),
        primary => 0
    };
    push(@$ref_categories, $category);
    my $category_iter = MT->model( 'category' )->load_iter({ parent => $parent->id }, {});
    while (my $obj = $category_iter->()) {
        _trace_category($ref_categories, $obj, $ref_chains);
    }

    pop(@$ref_chains);
}

sub _cb_tp_preview_entry {
    my ( $cb, $app, $param, $tmpl ) = @_;

    my $blog = $app->blog;

    return unless defined( $blog );
    return unless $app->param( '_type' ) eq 'entry';

    foreach my $key ( qw( multipost multipost_blog_id multipost_category_id ) ) {
        push @{ $param->{ 'entry_loop' } }, {
            data_name => $key,
            data_value => $app->param( $key )
        };
    }

    1;
}

sub _cb_ps_entry {
    my ( $cb, $app, $entry, $original ) = @_;

    return 1 unless $entry->class eq 'entry';

    return 1 unless $app->param( 'multipost' );

    my $target_blog_id = $app->param( 'multipost_blog_id' );
    my $target_category_id = $app->param( 'multipost_category_id' );
    return 1 unless $target_blog_id;

    my $target_blog = MT->model( 'blog' )->load( $target_blog_id );
    return 1 unless defined($target_blog) && $target_blog->id != $entry->blog_id;

    return 1 unless _can_on_blog( $app->user, $target_blog, 'create_post' );

    local $app->{_blog} = $target_blog;

    my $target_category;
    if ( $target_category_id ) {
        $target_category = MT->model( 'category' )->load(
            { id => $target_category_id, blog_id => $target_blog->id },
            { limit => 1 }
        );
    }
    
    my $new_entry = $entry->clone;
    $new_entry->id( undef );
    $new_entry->blog_id( $target_blog->id );
    $new_entry->category_id( undef );
    $new_entry->modified_on( undef );
    $new_entry->created_on( undef );
    $new_entry->status( MT::Entry::HOLD() )
      unless _can_on_blog( $app->user, $target_blog, 'publish_post' );
    
    my @asset_ids = split( ',', $app->param('include_asset_ids') || '' );
    my @new_assets = ();
    if ( _can_on_blog( $app->user, $target_blog, 'upload' ) ) {
        foreach my $asset_id ( @asset_ids ) {
            my $asset = MT->model( 'asset' )->load( $asset_id );
            next unless $asset;
            my $new_asset = $asset->clone;
            $new_asset->id( undef );
            $new_asset->blog_id( $target_blog->id );
            $new_asset->modified_on( undef );
            $new_asset->created_on( undef );
            
            require MT::FileMgr;
            my $fmgr = MT::FileMgr->new( 'Local' ) or die MT::FileMgr->errstr;;
            my $dir = dirname( $new_asset->file_path );
            $fmgr->mkpath( $dir ) or return MT->trans_error( "Error making path '[_1]': [_2]",
                                                             $new_asset->file_path, $fmgr->errstr );
            $fmgr->put_data( $fmgr->get_data( $asset->file_path ), $new_asset->file_path, 'upload' );
            
            if ( $new_asset->save ) {
                push @new_assets, $new_asset;
                
                foreach my $key ( qw( text text_more ) ) {
                    my $text = $new_entry->$key;
                    $text =~ s/@{[ $asset->url ]}/@{[ $new_asset->url ]}/g;
                    $new_entry->$key( $text );
                }
            }
        }
    }

    $app->run_callbacks( 'cms_pre_save.entry', $app, $new_entry, undef )
        || return $app->error(
        $app->translate(
            "Saving [_1] failed: [_2]",
            MT->model( 'entry' )->class_label, $app->errstr
        )
    );

    $new_entry->save
      or return $app->error(
        $app->translate(
            "Saving [_1] failed: [_2]",
            MT->model( 'entry' )->class_label, $new_entry->errstr
        )
    );

    foreach my $new_asset ( @new_assets ) {
        my $obj_asset = MT->model( 'objectasset' )->new;
        $obj_asset->blog_id( $new_entry->blog_id);
        $obj_asset->asset_id( $new_asset->id );
        $obj_asset->object_ds( 'entry' );
        $obj_asset->object_id( $new_entry->id );
        $obj_asset->save;
    }


    if ( defined $target_category ) {
        my $place = MT->model( 'placement')->new;
        $place->entry_id( $new_entry->id );
        $place->blog_id( $new_entry->blog_id );
        $place->is_primary(1);
        $place->category_id($target_category->id);
        $place->save;
        $new_entry->cache_property( 'category', undef, $target_category );
    }

    $app->run_callbacks( 'cms_post_save.entry', $app, $new_entry, undef );

    _rebuild_entry( $new_entry );

    1;
}


# 記事が「公開」なら再構築
sub _rebuild_entry {
    my ( $entry ) = @_;

    return unless $entry->status == MT::Entry::RELEASE();
    
    my $publisher = MT::WeblogPublisher->new;
    my $ret = $publisher->rebuild_entry(
        Entry => $entry,
        Blog => $entry->blog,
        BuildDependencies => 1
    );

    $ret;
}



sub _can_administer_blog {
    my ( $user, $blog ) = @_;

    if ( $blog && ( ref $blog ne 'MT::Blog' ) ) {
        $blog = undef;
    }
    return 0 unless $blog;

    return 1 if $user->is_superuser;

    return 0 unless my $perm = $user->permissions( $blog->id );

    #return 1 if $perm->can_administer_website;
    return 1 if $perm->can_administer_blog;

    return 0;
}

# 指定のブログで指定の操作が可能か
# _can_on_blog( $user, $blog, 'create_post' );
sub _can_on_blog {
    my ( $user, $blog, $action ) = @_;
    return 0 unless $blog;
    return 0 unless $user;
    return 1 if _can_administer_blog( $user, $blog );

    my $perms = MT::Permission->load({
        blog_id => $blog->id,
        author_id => $user->id});
    my $can_action = "can_$action";
    $perms && $perms->$can_action();
}

1;

  
