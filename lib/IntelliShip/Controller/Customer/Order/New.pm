package IntelliShip::Controller::Customer::Order::New;
use Moose;
use namespace::autoclean;

BEGIN { extends 'IntelliShip::Controller::Customer::Order'; }

=head1 NAME

IntelliShip::Controller::Customer::Order::New - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    #$c->response->body('Matched IntelliShip::Controller::Customer::Order::New in Customer::Order::New.');

	my $do_value = $c->req->param('do') || '';

	if ($do_value eq 'save')
		{
		$self->save_order;
		}
	elsif ( $do_value eq 'quick')
		{
		$self->setup_one_page;
		}
	else
		{
		$self->setup_one_page;
		}
	}

=encoding utf8

=head1 AUTHOR

root

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
