package IntelliShip::Controller::Customer::Ajax;
use Moose;
use Data::Dumper;
use namespace::autoclean;
use IntelliShip::HTTP;
use IntelliShip::Utils;
use IntelliShip::DateUtils;
use IntelliShip::Arrs::API;

BEGIN { extends 'IntelliShip::Controller::Customer'; }

=head1 NAME

IntelliShip::Controller::Customer::Ajax - Catalyst Controller

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
	}

sub get_HTML :Private
	{
	my $self = shift;
	my $c = $self->context;

	my $action = $c->req->param('action');
	if ($action eq 'display_international')
		{
		$self->set_international_details;
		}
	elsif ($action eq 'customer_carrier_chkbox')
		{
		$self->set_customer_carrier_chkbox;
		}
	elsif ($action eq 'costatus_chkbox')
		{
		$self->set_costatus_chkbox;
		}
	elsif ($c->req->param('action') eq 'get_customer_service_list')
		{
		$self->get_carrier_service_list;
		}

	$c->stash(template => "templates/customer/ajax.tt");
	}

sub set_international_details
	{
	my $self = shift;
	my $c = $self->context;

	$c->stash->{INTERNATIONAL} = 1;
	$c->stash->{countrylist_loop} = $self->get_select_list('COUNTRY');
	$c->stash->{currencylist_loop} = $self->get_select_list('CURRENCY');
	$c->stash->{dimentionlist_loop} = $self->get_select_list('DIMENTION');
	}

sub set_customer_carrier_chkbox
	{
	my $self = shift;
	my $c = $self->context;

	$c->stash->{CARRIER_LIST} = $self->get_select_list('CUSTOMER_SHIPMENT_CARRIER');
	}

sub set_costatus_chkbox
	{
	my $self = shift;
	my $c = $self->context;

	$c->stash->{COSTATUS_LIST} = $self->get_select_list('COSTATUS');
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
	elsif ($params->{'action'} eq 'adjust_due_date')
		{
		$dataHash = $self->adjust_due_date;
		}
	elsif ($params->{'action'} eq 'add_pkg_detail_row')
		{
		$dataHash = $self->add_pkg_detail_row;
		}
	elsif ($params->{'action'} eq 'get_freight_class')
		{
		$dataHash = $self->get_freight_class;
		}
	elsif ($c->req->param('action') eq 'third_party_delivery')
		{
		$dataHash = $self->set_third_party_delivery;
		}
	elsif ($c->req->param('action') eq 'get_city_state')
		{
		$dataHash = $self->get_city_state;
		}
	elsif ($c->req->param('action') eq 'get_address_detail')
		{
		$dataHash = $self->get_address_detail;
		}
	else
		{
		$dataHash = { error => '[Unknown request] Something went wrong, please contact support.' };
		}

	#$c->log->debug("\n TO dataHash:  " . Dumper ($dataHash));
	my $json_DATA = IntelliShip::Utils->jsonify($dataHash);
	#$c->log->debug("\n TO json_DATA:  " . Dumper ($json_DATA));
	$c->response->body($json_DATA);
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

sub adjust_due_date
	{
	my $self = shift;
	my $c = $self->context;
	my $params = $c->req->params;

	my $ship_date = $params->{shipdate};
	my $due_date = $params->{duedate};
	my $equal_offset = $params->{offset};
	my $less_than_offset = $params->{lessthanoffset};

	$c->log->debug("Ajax : adjust_due_date");
	$c->log->debug("ship_date : $ship_date");
	$c->log->debug("due_date : $due_date");
	$c->log->debug("equal_offset : $equal_offset");
	#$c->log->debug("less_than_offset : $less_than_offset");

	my $delta_days = IntelliShip::DateUtils->get_delta_days($ship_date,$due_date);

	$c->log->debug("delta_days : $delta_days");

	my ($offset, $adjusted_datetime);
	if ( $delta_days == 0 and length $equal_offset )
		{
		$offset = $equal_offset;
		}
	elsif ( $delta_days < 0 and length $less_than_offset )
		{
		$offset = $less_than_offset;
		}
	else
		{
		$adjusted_datetime = $due_date;
		}

	$adjusted_datetime = IntelliShip::DateUtils->get_future_business_date($ship_date, $offset) if $offset;

	$c->log->debug("adjusted_datetime : $adjusted_datetime");

	return { dateneeded => $adjusted_datetime };
	}

sub add_pkg_detail_row :Private
	{
	my $self = shift;
	my $c = $self->context;
	my $params = $c->req->params;

	$c->stash->{PKG_DETAIL_ROW} = 1;
	$c->stash->{ROW_COUNT} = $params->{'row_ID'};
	$c->stash->{DETAIL_TYPE} = $params->{'detail_type'};
	$c->stash->{packageunittype_loop} = $self->get_select_list('UNIT_TYPE');

	#$self->context->log->debug("in add_new_row : row_HTML");
	my $row_HTML = $c->forward($c->view('Ajax'), "render", [ "templates/customer/ajax.tt" ]);
	$c->stash->{PKG_DETAIL_ROW} = 0;

	return { rowHTML => $row_HTML };
	}

sub set_third_party_delivery
	{
	my $self = shift;
	my $c = $self->context;

	$c->stash->{statelist_loop} = $self->get_select_list('US_STATES');
	$c->stash->{countrylist_loop} = $self->get_select_list('COUNTRY');
	$c->stash->{THIRD_PARTY_DELIVERY} = 1;
	my $row_HTML = $c->forward($c->view('Ajax'), "render", [ "templates/customer/ajax.tt" ]);
	$c->stash->{THIRD_PARTY_DELIVERY} = 0;

	#$self->context->log->debug("set_third_party_delivery : " . $row_HTML);
	return { rowHTML => $row_HTML };
	}

sub get_freight_class :Private
	{
	my $self = shift;
	my $c = $self->context;
	my $params = $c->req->params;
	my $response_hash = { freight_class => IntelliShip::Utils->get_freight_class_from_density(undef,undef,undef,undef,$params->{'density'}) };
	#$c->log->debug("response_hash : " . Dumper $response_hash);
	return $response_hash;
	}

sub get_city_state
	{
	my $self = shift;
	my $c = $self->context;
	my $params = $c->req->params;

	my $address = $params->{'zipcode'};

	my $HTTP = IntelliShip::HTTP->new;
	$HTTP->method('GET');
	$HTTP->host_production('maps.googleapis.com/maps/api/geocode/xml');
	$HTTP->uri_production('address=' . $address . '&sensor=true');
	$HTTP->timeout('30');

	my $result = $HTTP->send;
	my $responseDS = IntelliShip::Utils->parse_XML($result);
	#$c->log->debug("get_city_state result : " . Dumper $result);
	#$c->log->debug("get_city_state responseDS : " . Dumper $responseDS);

	my ($address1, $address2, $city, $state, $zip, $country);
	if ($responseDS->{'GeocodeResponse'}->{'status'} eq 'OK')
		{
		my $geocodeResponse = $responseDS->{'GeocodeResponse'}->{'result'};
		my $formatted_address = $geocodeResponse->{'formatted_address'};
		my $address_components = $geocodeResponse->{'address_component'};

		foreach my $component (@$address_components)
			{
			#$c->log->debug("ref component->{type}: " . ref $component->{type});
			$component->{type} = join(' | ', @{$component->{type}}) if (ref $component->{type}) =~ /array/gi;
			#$c->log->debug("component->{type}: " . $component->{type});

			$city = $component->{short_name} if $component->{type} =~ /locality/;
			$state = $component->{short_name} if $component->{type} =~ /administrative_area_level_1/;
			$zip = $component->{short_name} if $component->{type} =~ /postal_code/;
			$country = $component->{short_name} if $component->{type} =~ /country/;
			}
		}

	#$c->log->debug("address1: $address1, address2: $address2, city: $city, state: $state, zip: $zip, country: $country");

	return { city => $city, state => $state, zip => $zip, country => $country };
	}

sub get_address_detail
	{
	my $self = shift;
	my $c = $self->context;

	my $addressid = $c->req->params->{'addressid'};
	my $Address = $self->context->model('MyDBI::Address')->find({addressid => $addressid});

	return { address1 => $Address->address1, address2 => $Address->address2, city => $Address->city, state => $Address->state, zip => $Address->zip, country => $Address->country };
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
