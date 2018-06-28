#
# Copyright (C) 2016- The University of Notre Dame
# This software is distributed under the GNU General Public License.
# See the file COPYING for details.
#

use v5.09;
use strict;
use warnings;

package VC3::Source::Container;
use base 'VC3::Source::System';
use JSON::Tiny;
use Carp;
use File::Copy;
use File::Spec::Functions qw/catfile file_name_is_absolute/;

sub new {
    my ($class, $widget, $json_description) = @_;

    if($widget->wrapper) {
        die "Wrapper specified in conflict with '" . $widget->package->name . "'\n";
    }


    my $self = $class->SUPER::new($widget, $json_description);

    # anything with a Container source becomes an operating system
    $self->widget->package->type('operating-system');

    my $image = $json_description->{image};
    unless($image) {
        die "No image specified for '" . $widget->package->name . "'\n";
    }

    $json_description->{'images-directory'} ||= 'images';

    if($image =~ m^://^ or file_name_is_absolute($image)) {
        $self->image($image);
    } else {
        $image = catfile($json_description->{'images-directory'}, $image);
        $self->image(catfile($self->widget->package->bag->files_dir, $image));
        push @{$self->files}, $image;
    }

    return $self;
}

sub setup_wrapper {
    my ($self, $exe, $builder_args, $mount_map) = @_;

    die "Container Source did not define a wrapper.\n";
}

sub to_hash {
    my ($self) = @_;

    my $sh = $self->SUPER::to_hash();
    $sh->{image} = $self->image;

    # wrapper is generated automatically:
    delete $sh->{wrapper};

    return $sh;
}

sub image {
    my ($self, $new_image) = @_;

    $self->{image} = $new_image if($new_image);

    unless($self->{image}) {
        die "Container recipe for '" . $self->widget->package->name . "' did not define an 'image' field.\n";
    }
    
    return $self->{image};
}

sub prepare_recipe_sandbox {
    my ($self, $exe, $builder_args, $payload_args, $mount_map) = @_;

    $self->get_files();

    my $bag = $self->widget->package->bag;
    my ($root, $home, $files, $tmp) = ($bag->root_dir, $bag->home_dir, $bag->files_dir, $bag->tmp_dir);

    my $root_target  = $self->add_mount($mount_map, $bag->root_dir,  '/vc3/vc3-root');
    my $home_target  = $self->add_mount($mount_map, $bag->home_dir,  '/vc3/vc3-home');
    my $files_target = $self->add_mount($mount_map, $bag->files_dir, '/vc3/vc3-distfiles');

    my $builder_path = catfile($bag->tmp_dir, 'vc3-builder');
    copy($0, $builder_path);
    chmod 0755, $builder_path;

    my $recipe_path = catfile($bag->tmp_dir, 'vc3-recipes');
    copy($bag->sh_profile . '.recipes', $recipe_path);

    my @new_builder_args;
    push @new_builder_args, catfile($root_target, 'tmp', 'vc3-builder');
    push @new_builder_args, '--no-os-switch';
    push @new_builder_args, $self->remove_args(@{$builder_args});
    push @new_builder_args, ('--install',   $root_target);
    push @new_builder_args, ('--distfiles', $files_target);
    push @new_builder_args, ('--home',      $home_target);
    push @new_builder_args, ('--database',  catfile($root_target, 'tmp', 'vc3-recipes'));


    if(scalar @{$payload_args} > 0) {
        push @new_builder_args, '--';
        push @new_builder_args, @{$payload_args};
    }

    my $wrapper = $self->setup_wrapper($exe, \@new_builder_args, $mount_map);

    $self->widget->wrapper($wrapper);
}

sub add_mount {
    my ($self, $mount_map, $from, $default_target) = @_;

    unless($mount_map->{$from}) {
        $mount_map->{$from} = $default_target;
    }

    return $mount_map->{$from};
}

sub remove_args {
    my ($self, @args) = @_;

    my @builder_args;

    my $prev_no_equal = 0;
    for my $a (@args) {
        if($prev_no_equal) {
            $prev_no_equal = 0;
            next;
        }

        if($a =~ m/^--mount=/) {
            next;
        }

        if($a =~ m/^--mount$/) {
            $prev_no_equal = 1;
            next;
        }

        if($a =~ m/^--database=/) {
            next;
        }

        if($a =~ m/^--database$/) {
            $prev_no_equal = 1;
            next;
        }

        push @builder_args, $a;
    }

    return @builder_args;
}

1;

