package IntelliShip::Controller::Customer::Order::Ajax;
use Moose;
use Data::Dumper;
use namespace::autoclean;
use IntelliShip::DateUtils;

BEGIN { extends 'IntelliShip::Controller::Customer::Order'; }

=head1 NAME

IntelliShip::Controller::Customer::Order::Ajax - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0)
	{
	my ( $self, $c ) = @_;
	my $params = $c->req->params;

	if ($params->{'type'} eq 'HTML')
		{
		$self->get_HTML;
		}
	elsif ($params->{'type'} eq 'JSON')
		{
		$self->get_JSON_DATA;
		}

	$c->stash(template => "templates/customer/order-ajax.tt");
	}

sub get_HTML :Private
	{
	my $self = shift;
	my $c = $self->context;

	if ($c->req->param('action') eq 'display_international')
		{
		$self->set_international_details;
		}
	}

sub set_international_details
	{
	my $self = shift;
	my $c = $self->context;

	$c->stash->{countrylist_loop} = $self->get_select_list('COUNTRY');
	$c->stash->{INTERNATIONAL} = 1;
	}

sub get_JSON_DATA :Private
	{
	my $self = shift;
	my $c = $self->context;
	my $params = $c->req->params;

	my $dataHash;
	if ($params->{'action'} eq 'get_sku_detail')
		{
		$dataHash = $self->get_sku_detail;
		}

	#$c->log->debug("\n TO dataHash:  " . Dumper ($dataHash));
	my $json_response = $self->jsonify($dataHash);
	#$c->log->debug("\n TO json_response:  " . Dumper ($json_response));

	$c->stash->{JSON_DATA} = $json_response;
	}

sub get_sku_detail :Private
	{
	my $self = shift;
	my $c = $self->context;
	my $params = $c->req->params;

	my $where = {customerskuid => $params->{'sku_id'}};

	my @sku = $c->model("MyDBI::Productsku")->search($where);
	my $SkuObj = $sku[0];

	my $response_hash = {};
	if ($SkuObj)
		{
		$response_hash->{'description'} = $SkuObj->description;
		$response_hash->{'weight'} = $SkuObj->weight;
		$response_hash->{'length'} = $SkuObj->length;
		$response_hash->{'width'} = $SkuObj->width;
		$response_hash->{'height'} = $SkuObj->height;
		$response_hash->{'nmfc'} = $SkuObj->nmfc;
		$response_hash->{'class'} = $SkuObj->class;
		$response_hash->{'unittypeid'} = $SkuObj->unittypeid;
		$response_hash->{'unitofmeasure'} = $SkuObj->unitofmeasure;
		}
	else
		{
		$response_hash->{'error'} = "Sku not found";
		}

	return $response_hash;
	}

sub jsonify
	{
	my $self = shift;
	my $struct = shift;
	my $json = [];
	if (ref($struct) eq "ARRAY")
		{
		my $list = [];
		foreach my $item (@$struct)
			{
				if (ref($item) eq "" ){
					$item = $self->clean_json_data($item);
					push @$list, "\"$item\"";
				}
				else{
					push @$list, $self->jsonify($item);
				}
			}
		return "[" . join(",",@$list) . "]";

		}
	elsif (ref($struct) eq "HASH")
		{
		my $list = [];
		foreach my $key (keys %$struct)
			{
			my $val = $struct->{$key};
			if (ref($val) eq "" )
				{
				$val = $self->clean_json_data($val);
				push @$list, "\"$key\":\"$val\"";
				}
			else
				{
				push @$list, "\"$key\":" . $self->jsonify($struct->{$key});
				}
			}
		return "{" . join(',',@$list) . "}";
		}
	}

sub clean_json_data
	{
	my $self = shift;
	my $item = shift;

	$item =~ s/"/\\"/g;
	$item =~ s/[\n\t]//g;

	return $item;
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
