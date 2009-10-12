#! /usr/bin/perl
use Modern::Perl;

use MooseX::Declare;

class Troller {
    use Data::Dump;
    use Gtk2;
    use Cairo;

    use constant SPEED => 400; #pxls per sec

    has 'y_offset'      => (is => 'ro', isa => 'Int',
        default => sub { @{shift->bus->trollers} * 200 });

    has 'x_offset'      => (is => 'rw', isa => 'Int',
        default => sub { shift->bus->width }, lazy => 1 );

    has 'x_offset_limit'=> (is => 'rw', isa => 'Int');
    has 'text'          => (is => 'rw', isa => 'Str');
    has 'bus'           => (is => 'ro', isa => 'TrollerBus',
        required => 1, weak_ref => 1);

    method draw($cr) {
        if ($self->text) {
            my $std_extents = $cr->text_extents("M");
            unless ($self->x_offset_limit) {
                my $extents = $cr->text_extents($self->text);
                $self->x_offset_limit(-($extents->{width} + $extents->{x_bearing}));
            }

            $cr->move_to($self->x_offset, $self->y_offset + $std_extents->{height} + 30);
            $cr->text_path($self->text);
            $cr->set_source_rgba(0, 0, 0, 0.7);
            $cr->stroke_preserve();
            $cr->set_source_rgb(1, 1, 1);
            $cr->fill();
        }

        return 1;
    }

    method move_step() {
        $self->x_offset($self->x_offset - int(SPEED / (1000 / 30)));

        if ($self->x_offset_limit && $self->x_offset < $self->x_offset_limit) {
            $self->bus->remove($self);
        }

        return 1;
    }
}

class TrollerBus {
    use Data::Dump;
    use Gtk2 -init;
    use List::MoreUtils qw/firstidx/;

    has 'font_size'     => (is => 'ro', isa => 'Int', default => 100);

    has 'width'         => (is => 'rw', isa => 'Int');

    has 'trollers'      => (is => 'rw', isa => 'ArrayRef[Troller]',
        default => sub {[]} );

    has '_window'       => (is => 'ro', isa => 'Gtk2::Window',
        builder         => '_build_window');

    method _build_window {
        my $win = Gtk2::Window->new('toplevel');
        my $scr = $win->get_screen;
        $self->width($scr->get_width);
        $win->set_size_request($scr->get_width, $scr->get_height);

        $self->_buff_window($win);

        $win->signal_connect('screen-changed' => sub { $self->_screen_changed(@_) });
        $win->signal_connect('expose-event'   => sub { $self->_window_exposed(@_) });

        $win->show_all;

        Glib::Timeout->add(30, sub {
            my $need_redraw = 0;
            for my $troller (grep {$_} @{$self->trollers}) {
                $need_redraw = $troller->move_step() || $need_redraw;
            }
            $win->queue_draw if $need_redraw;

            return 1;
        });

        return $win;
    }

    method _buff_window(Object $win) {
        #remove default background
        $self->_screen_changed($win);
	$win->realize;
	$win->window->set_back_pixmap(undef, 0);

        $win->window->set_override_redirect(1);
	$win->set_keep_above (1);
	$win->set_resizable(0);
	$win->set_accept_focus(0);
	$win->set_app_paintable(1);
	$win->set_decorated(0);
	$win->set_type_hint('notification');
	$win->set_skip_pager_hint(1);
	$win->set_skip_taskbar_hint(1);
	$win->stick;

        # make clicks go through
        my ($width, $height) = $win->get_size_request;

	my $shape_mask = Gtk2::Gdk::Pixmap->new(undef, $width, $height, 1);

        if ($shape_mask) {
            $win->input_shape_combine_mask(undef, 0, 0);
            # combine with empty mask to get all clicks to go through
            $win->input_shape_combine_mask($shape_mask, 0, 0);
	}

        return $win;
    }

    method _screen_changed($win) {
        my $scr = $win->get_screen;
        my $colormap = $scr->get_rgba_colormap
            or die "Cannot get RGBA colormap, your display probably does not support Alpha\n";

        $win->set_colormap($colormap);
    }

    method _window_exposed($win, $event, $data?) {
        my $cr = Gtk2::Gdk::Cairo::Context->create($win->window);

        $cr->scale(1.0, 1.0);
        $cr->set_operator('clear');
        $cr->paint;

        $cr->set_line_width(13);
        $cr->set_line_join('round');

        unless (@{$self->trollers}) {
            return 1;
        }

        $cr->set_operator('source');
        $cr->select_font_face('sans serif', 'normal', 'bold');
        $cr->set_font_size($self->font_size);

        for my $troller (grep {$_} @{$self->trollers}) {
            $troller->draw($cr);
        }

        return 1;
    }

# ===========================================================================
# ===========================================================================
# ===========================================================================

    method add(Str $str) {
        push @{$self->trollers},
            Troller->new(bus => $self, text => $str);
    }

    method remove(Troller $tr) {
        delete $self->trollers->[firstidx { ($_ || '') eq $tr } @{$self->trollers}];
    }

    method do_iteration() {
        Gtk2->main_iteration_do(0);
    }
}

use AnyEvent;

my $trollers = new TrollerBus;

my $read_stdin = AnyEvent->io(
    fh  => \*STDIN, poll => 'r',
    cb  => sub {
        chomp(my $str = <STDIN>);
        $trollers->add($str) if $str;
    }
);

while(1) {
    $trollers->do_iteration;
}
