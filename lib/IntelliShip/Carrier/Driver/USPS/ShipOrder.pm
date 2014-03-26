package IntelliShip::Carrier::Driver::USPS::ShipOrder;

use Moose;
use XML::Simple;
use Data::Dumper;
use LWP::UserAgent;
use IntelliShip::DateUtils;
use HTTP::Request::Common;
use IntelliShip::MyConfig;

BEGIN { extends 'IntelliShip::Carrier::Driver'; }

sub process_request
	{
	my $self = shift;

	my $CO = $self->CO;
	my $Customer = $CO->customer;
	my $shipmentData = $self->data;

	$self->log("Process USPS Ship Order");

	#$self->log("Shipment Data" .Dumper($shipmentData));

	my ($API_name,$XML_request) = ('','');

	if ($shipmentData->{'servicecode'} eq 'USPSF')
		{
		$XML_request = $self->get_FirstClass_xml_request;
		$API_name = 'DeliveryConfirmationV4';
		}
	elsif ($shipmentData->{'servicecode'} eq 'USTPO')
		{
		$XML_request = $self->get_StandardPost_xml_request;
		$API_name = 'DeliveryConfirmationV4';
		}
	elsif ($shipmentData->{'servicecode'} eq 'UPRIORITY')
		{
		$XML_request = $self->get_PriorityMail_xml_request;
		$API_name = 'DeliveryConfirmationV4';
		}
		elsif ($shipmentData->{'servicecode'} eq 'USPSMM')
		{
		$XML_request = $self->get_MediaMail_xml_request;
		$API_name = 'DeliveryConfirmationV4';
		}
		elsif ($shipmentData->{'servicecode'} eq 'USPSLM')
		{
		$XML_request = $self->get_LibraryMail_xml_request;
		$API_name = 'DeliveryConfirmationV4';
		}
	elsif ($shipmentData->{'servicecode'} eq 'UPME')
		{
		$XML_request = $self->get_PriorityMailExpress_xml_request;
		$API_name = 'ExpressMailLabel';
		}

	my $url = 'https://secure.shippingapis.com/' . (IntelliShip::MyConfig->getDomain eq 'PRODUCTION' ? 'ShippingAPI.dll' : 'ShippingAPITest.dll');
	$self->log("Sending request to URL: " . $url);

	my $shupment_request = {
			httpurl => $url,
			API => $API_name,
			XML => $XML_request
		};

	my $UserAgent = LWP::UserAgent->new();
	my $response = $UserAgent->request(
			POST $shupment_request->{'httpurl'},
			Content_Type  => 'text/html',
			Content       => [%$shupment_request]
			);

	unless ($response)
		{
		$self->log("USPS: Unable to access USPS site");
		$self->add_error("No response received from USPS");
		return $shipmentData;
		}

	#$self->log( "### RESPONSE IS SUCCESS: " . $response->is_success);
	#$self->log( "### RESPONSE DETAILS: " . Dumper $response->content);

	my $xml = new XML::Simple;

	my $XMLResponse = $xml->XMLin($response->content);

	if( $XMLResponse->{Number} and $XMLResponse->{Description})
		{
		my $msg = "Carrier Response Error: ".$XMLResponse->{Number}. " : ". $XMLResponse->{Description};
		$self->log($msg);
		$self->add_error($msg);
		return $shipmentData;
		}

	my $TrackingNumber =$XMLResponse->{DeliveryConfirmationNumber};
	$self->log("DeliveryConfirmationNumber: ".$TrackingNumber);

	$shipmentData->{'barcodedata'} = $TrackingNumber ;

	$TrackingNumber = substr ($TrackingNumber, -22);
	$self->log("TrackingNumber: ".$TrackingNumber);

	$shipmentData->{'tracking1'}    = $TrackingNumber;
	$shipmentData->{'weight'}       = $shipmentData->{'enteredweight'};
	$shipmentData->{'RDC'}          = $XMLResponse->{RDC};
	$shipmentData->{'CarrierRoute'} = $XMLResponse->{CarrierRoute};
	$shipmentData->{'expectedDelivery'} = $XMLResponse->{Commitment}->{ScheduledDeliveryDate} if  $XMLResponse->{Commitment}->{ScheduledDeliveryDate};
	$shipmentData->{'expectedDelivery'} = IntelliShip::DateUtils->american_date($shipmentData->{'expectedDelivery'}) if $shipmentData->{'expectedDelivery'};
	$shipmentData->{'commintmentName'} = uc($XMLResponse->{Commitment}->{CommitmentName}) if  $XMLResponse->{Commitment}->{CommitmentName};

	my $raw_string = $self->get_EPL($shipmentData);
	my $PrinterString = $raw_string;

	$shipmentData->{'printerstring'} = $PrinterString;

	$self->insert_shipment($shipmentData);
	$self->response->printer_string($PrinterString);
	}

sub get_FirstClass_xml_request
	{
	my $self = shift;
	my $shipmentData = $self->data;
	my $CO = $self->CO;
	my $Contact = $CO->contact;

	$self->log("### Get XML Request for First Class Mail ###: " );
	#$self->log("### Get XML Request ###: " . Dumper $shipmentData);

		$shipmentData->{serviceType} = 'First Class';

	#$self->log("### Service Type" .$shipmentData->{serviceType} );

	$shipmentData->{FromName} =  $Contact->firstname.' '.$Contact->lastname;
	$shipmentData->{'weightinounces'} = $shipmentData->{'enteredweight'};
	$shipmentData->{'dimheight'} = $shipmentData->{'dimheight'} ? $shipmentData->{'dimheight'} : 10;
	$shipmentData->{'dimwidth'} = $shipmentData->{'dimwidth'} ? $shipmentData->{'dimwidth'} : 10;
	$shipmentData->{'dimlength'} = $shipmentData->{'dimlength'} ? $shipmentData->{'dimlength'} : 10;

	#$self->log("Senders Name ". $shipmentData->{FromName});

	if($shipmentData->{'dimheight'} > 12 or $shipmentData->{'dimwidth'} > 12 or $shipmentData->{'dimlength'} >12)
		{
		$shipmentData->{'packagesize'} = 'LARGE';
		}
	else
		{
		$shipmentData->{'packagesize'} = 'REGULAR';
		}

	my $XML_request = <<END;
<?xml version="1.0" encoding="UTF-8" ?>
<DeliveryConfirmationV4.0Request USERID="667ENGAG1719" PASSWORD="044BD12WF954">
<Revision>2</Revision>
<ImageParameters />
<FromName>$shipmentData->{FromName}</FromName>
<FromFirm>$shipmentData->{'customername'}</FromFirm>
<FromAddress1>$shipmentData->{'branchaddress2'}</FromAddress1>
<FromAddress2>$shipmentData->{'branchaddress1'}</FromAddress2>
<FromCity>$shipmentData->{'branchaddresscity'}</FromCity>
<FromState>$shipmentData->{'branchaddressstate'}</FromState>
<FromZip5>$shipmentData->{'branchaddresszip'}</FromZip5>
<FromZip4/>
<ToName>$shipmentData->{'contactname'}</ToName>
<ToFirm>$shipmentData->{'addressname'}</ToFirm>
<ToAddress1>$shipmentData->{'address1'}</ToAddress1>
<ToAddress2>$shipmentData->{'address2'}</ToAddress2>
<ToCity>$shipmentData->{'addresscity'}</ToCity>
<ToState>$shipmentData->{'addressstate'}</ToState>
<ToZip5>$shipmentData->{'addresszip'}</ToZip5>
<ToZip4/>
<WeightInOunces>$shipmentData->{'weightinounces'}</WeightInOunces>
<ServiceType>$shipmentData->{serviceType}</ServiceType>
<SeparateReceiptPage>True</SeparateReceiptPage>
<ImageType>TIF</ImageType>
<AddressServiceRequested>False</AddressServiceRequested>
<HoldForManifest>N</HoldForManifest>
<Size>$shipmentData->{'packagesize'}</Size>
<Width>$shipmentData->{'dimheight'}</Width>
<Length>$shipmentData->{'dimwidth'}</Length>
<Height>$shipmentData->{'dimlength'}</Height>
<ReturnCommitments>true</ReturnCommitments>
</DeliveryConfirmationV4.0Request>
END

	#$self->log("... XML Request Data:  " . $XML_request);

	return $XML_request;
	}

sub get_StandardPost_xml_request
	{
	my $self = shift;
	my $shipmentData = $self->data;
	my $CO = $self->CO;
	my $Contact = $CO->contact;

	$self->log("### Get XML Request for Standar Post ###: " );
	#$self->log("### Get XML Request ###: " . Dumper $shipmentData);

		$shipmentData->{serviceType} = 'Standard Post';

	#$self->log("### Service Type" .$shipmentData->{serviceType} );

	$shipmentData->{FromName} =  $Contact->firstname.' '.$Contact->lastname;
	$shipmentData->{'weightinounces'} = $shipmentData->{'enteredweight'};
	$shipmentData->{'dimheight'} = $shipmentData->{'dimheight'} ? $shipmentData->{'dimheight'} : 10;
	$shipmentData->{'dimwidth'} = $shipmentData->{'dimwidth'} ? $shipmentData->{'dimwidth'} : 10;
	$shipmentData->{'dimlength'} = $shipmentData->{'dimlength'} ? $shipmentData->{'dimlength'} : 10;

	#$self->log("Senders Name ". $shipmentData->{FromName});

	if($shipmentData->{'dimheight'} > 12 or $shipmentData->{'dimwidth'} > 12 or $shipmentData->{'dimlength'} >12)
		{
		$shipmentData->{'packagesize'} = 'LARGE';
		}
	else
		{
		$shipmentData->{'packagesize'} = 'REGULAR';
		}

	my $XML_request = <<END;
<?xml version="1.0" encoding="UTF-8" ?>
<DeliveryConfirmationV4.0Request USERID="667ENGAG1719" PASSWORD="044BD12WF954">
<Revision>2</Revision>
<ImageParameters/>
<FromName>$shipmentData->{FromName}</FromName>
<FromFirm>$shipmentData->{'customername'}</FromFirm>
<FromAddress1>$shipmentData->{'branchaddress2'}</FromAddress1>
<FromAddress2>$shipmentData->{'branchaddress1'}</FromAddress2>
<FromCity>$shipmentData->{'branchaddresscity'}</FromCity>
<FromState>$shipmentData->{'branchaddressstate'}</FromState>
<FromZip5>$shipmentData->{'branchaddresszip'}</FromZip5>
<FromZip4/>
<ToName>$shipmentData->{'contactname'}</ToName>
<ToFirm>$shipmentData->{'addressname'}</ToFirm>
<ToAddress1>$shipmentData->{'address1'}</ToAddress1>
<ToAddress2>$shipmentData->{'address2'}</ToAddress2>
<ToCity>$shipmentData->{'addresscity'}</ToCity>
<ToState>$shipmentData->{'addressstate'}</ToState>
<ToZip5>$shipmentData->{'addresszip'}</ToZip5>
<ToZip4/>
<WeightInOunces>$shipmentData->{'weightinounces'}</WeightInOunces>
<ServiceType>$shipmentData->{serviceType}</ServiceType>
<SeparateReceiptPage>True</SeparateReceiptPage>
<ImageType>TIF</ImageType>
<AddressServiceRequested>False</AddressServiceRequested>
<HoldForManifest>N</HoldForManifest>
<Size>$shipmentData->{'packagesize'}</Size>
<Width>$shipmentData->{'dimheight'}</Width>
<Length>$shipmentData->{'dimwidth'}</Length>
<Height>$shipmentData->{'dimlength'}</Height>
<ReturnCommitments>true</ReturnCommitments>
<GroundOnly>True</GroundOnly>
</DeliveryConfirmationV4.0Request>
END

	#$self->log("... XML Request Data:  " . $XML_request);

	return $XML_request;
	}

sub get_PriorityMail_xml_request
	{
	my $self = shift;
	my $shipmentData = $self->data;
	my $CO = $self->CO;
	my $Contact = $CO->contact;

	$self->log("### Get XML Request for Priority Mail ###: " );
	#$self->log("### Get XML Request ###: " . Dumper $shipmentData);

		$shipmentData->{serviceType} = 'Priority';

	#$self->log("### Service Type" .$shipmentData->{serviceType} );

	$shipmentData->{FromName} =  $Contact->firstname.' '.$Contact->lastname;
	$shipmentData->{'weightinounces'} = $shipmentData->{'enteredweight'};
	$shipmentData->{'dimheight'} = $shipmentData->{'dimheight'} ? $shipmentData->{'dimheight'} : 10;
	$shipmentData->{'dimwidth'} = $shipmentData->{'dimwidth'} ? $shipmentData->{'dimwidth'} : 10;
	$shipmentData->{'dimlength'} = $shipmentData->{'dimlength'} ? $shipmentData->{'dimlength'} : 10;

	#$self->log("Senders Name ". $shipmentData->{FromName});

	if($shipmentData->{'dimheight'} > 12 or $shipmentData->{'dimwidth'} > 12 or $shipmentData->{'dimlength'} >12)
		{
		$shipmentData->{'packagesize'} = 'LARGE';
		}
	else
		{
		$shipmentData->{'packagesize'} = 'REGULAR';
		}

	my $XML_request = <<END;
<?xml version="1.0" encoding="UTF-8" ?>
<DeliveryConfirmationV4.0Request USERID="667ENGAG1719" PASSWORD="044BD12WF954">
<Revision>2</Revision>
<ImageParameters/>
<FromName>$shipmentData->{FromName}</FromName>
<FromFirm>$shipmentData->{'customername'}</FromFirm>
<FromAddress1>$shipmentData->{'branchaddress2'}</FromAddress1>
<FromAddress2>$shipmentData->{'branchaddress1'}</FromAddress2>
<FromCity>$shipmentData->{'branchaddresscity'}</FromCity>
<FromState>$shipmentData->{'branchaddressstate'}</FromState>
<FromZip5>$shipmentData->{'branchaddresszip'}</FromZip5>
<FromZip4/>
<ToName>$shipmentData->{'contactname'}</ToName>
<ToFirm>$shipmentData->{'addressname'}</ToFirm>
<ToAddress1>$shipmentData->{'address1'}</ToAddress1>
<ToAddress2>$shipmentData->{'address2'}</ToAddress2>
<ToCity>$shipmentData->{'addresscity'}</ToCity>
<ToState>$shipmentData->{'addressstate'}</ToState>
<ToZip5>$shipmentData->{'addresszip'}</ToZip5>
<ToZip4/>
<WeightInOunces>$shipmentData->{'weightinounces'}</WeightInOunces>
<ServiceType>$shipmentData->{serviceType}</ServiceType>
<SeparateReceiptPage>True</SeparateReceiptPage>
<ImageType>TIF</ImageType>
<AddressServiceRequested>False</AddressServiceRequested>
<HoldForManifest>N</HoldForManifest>
<Size>$shipmentData->{'packagesize'}</Size>
<Width>$shipmentData->{'dimheight'}</Width>
<Length>$shipmentData->{'dimwidth'}</Length>
<Height>$shipmentData->{'dimlength'}</Height>
<ReturnCommitments>true</ReturnCommitments>
</DeliveryConfirmationV4.0Request>
END

	#$self->log("... XML Request Data:  " . $XML_request);

	return $XML_request;
	}

sub get_MediaMail_xml_request
	{
	my $self = shift;
	my $shipmentData = $self->data;
	my $CO = $self->CO;
	my $Contact = $CO->contact;

	$self->log("### Get XML Request for Priority Mail ###: " );
	#$self->log("### Get XML Request ###: " . Dumper $shipmentData);

	$shipmentData->{serviceType} = 'Media Mail';

	#$self->log("### Service Type" .$shipmentData->{serviceType} );

	$shipmentData->{FromName} =  $Contact->firstname.' '.$Contact->lastname;
	$shipmentData->{'weightinounces'} = $shipmentData->{'enteredweight'};
	$shipmentData->{'dimheight'} = $shipmentData->{'dimheight'} ? $shipmentData->{'dimheight'} : 10;
	$shipmentData->{'dimwidth'} = $shipmentData->{'dimwidth'} ? $shipmentData->{'dimwidth'} : 10;
	$shipmentData->{'dimlength'} = $shipmentData->{'dimlength'} ? $shipmentData->{'dimlength'} : 10;

	#$self->log("Senders Name ". $shipmentData->{FromName});

	if($shipmentData->{'dimheight'} > 12 or $shipmentData->{'dimwidth'} > 12 or $shipmentData->{'dimlength'} >12)
		{
		$shipmentData->{'packagesize'} = 'LARGE';
		}
	else
		{
		$shipmentData->{'packagesize'} = 'REGULAR';
		}

	my $XML_request = <<END;
<?xml version="1.0" encoding="UTF-8" ?>
<DeliveryConfirmationV4.0Request USERID="667ENGAG1719" PASSWORD="044BD12WF954">
<Revision>2</Revision>
<ImageParameters/>
<FromName>$shipmentData->{FromName}</FromName>
<FromFirm>$shipmentData->{'customername'}</FromFirm>
<FromAddress1>$shipmentData->{'branchaddress2'}</FromAddress1>
<FromAddress2>$shipmentData->{'branchaddress1'}</FromAddress2>
<FromCity>$shipmentData->{'branchaddresscity'}</FromCity>
<FromState>$shipmentData->{'branchaddressstate'}</FromState>
<FromZip5>$shipmentData->{'branchaddresszip'}</FromZip5>
<FromZip4/>
<ToName>$shipmentData->{'contactname'}</ToName>
<ToFirm>$shipmentData->{'addressname'}</ToFirm>
<ToAddress1>$shipmentData->{'address1'}</ToAddress1>
<ToAddress2>$shipmentData->{'address2'}</ToAddress2>
<ToCity>$shipmentData->{'addresscity'}</ToCity>
<ToState>$shipmentData->{'addressstate'}</ToState>
<ToZip5>$shipmentData->{'addresszip'}</ToZip5>
<ToZip4/>
<WeightInOunces>$shipmentData->{'weightinounces'}</WeightInOunces>
<ServiceType>$shipmentData->{serviceType}</ServiceType>
<SeparateReceiptPage>True</SeparateReceiptPage>
<ImageType>TIF</ImageType>
<AddressServiceRequested>False</AddressServiceRequested>
<HoldForManifest>N</HoldForManifest>
<Size>$shipmentData->{'packagesize'}</Size>
<Width>$shipmentData->{'dimheight'}</Width>
<Length>$shipmentData->{'dimwidth'}</Length>
<Height>$shipmentData->{'dimlength'}</Height>
<ReturnCommitments>true</ReturnCommitments>
</DeliveryConfirmationV4.0Request>
END

	#$self->log("... XML Request Data:  " . $XML_request);

	return $XML_request;
	}

sub get_LibraryMail_xml_request
	{
	my $self = shift;
	my $shipmentData = $self->data;
	my $CO = $self->CO;
	my $Contact = $CO->contact;

	$self->log("### Get XML Request for Library Mail ###: " );
	#$self->log("### Get XML Request ###: " . Dumper $shipmentData);

	$shipmentData->{serviceType} = 'Library Mail';

	#$self->log("### Service Type" .$shipmentData->{serviceType} );

	$shipmentData->{FromName} =  $Contact->firstname.' '.$Contact->lastname;
	$shipmentData->{'weightinounces'} = $shipmentData->{'enteredweight'};
	$shipmentData->{'dimheight'} = $shipmentData->{'dimheight'} ? $shipmentData->{'dimheight'} : 10;
	$shipmentData->{'dimwidth'} = $shipmentData->{'dimwidth'} ? $shipmentData->{'dimwidth'} : 10;
	$shipmentData->{'dimlength'} = $shipmentData->{'dimlength'} ? $shipmentData->{'dimlength'} : 10;

	#$self->log("Senders Name ". $shipmentData->{FromName});

	if($shipmentData->{'dimheight'} > 12 or $shipmentData->{'dimwidth'} > 12 or $shipmentData->{'dimlength'} >12)
		{
		$shipmentData->{'packagesize'} = 'LARGE';
		}
	else
		{
		$shipmentData->{'packagesize'} = 'REGULAR';
		}

	my $XML_request = <<END;
<?xml version="1.0" encoding="UTF-8" ?>
<DeliveryConfirmationV4.0Request USERID="667ENGAG1719" PASSWORD="044BD12WF954">
<Revision>2</Revision>
<ImageParameters/>
<FromName>$shipmentData->{FromName}</FromName>
<FromFirm>$shipmentData->{'customername'}</FromFirm>
<FromAddress1>$shipmentData->{'branchaddress2'}</FromAddress1>
<FromAddress2>$shipmentData->{'branchaddress1'}</FromAddress2>
<FromCity>$shipmentData->{'branchaddresscity'}</FromCity>
<FromState>$shipmentData->{'branchaddressstate'}</FromState>
<FromZip5>$shipmentData->{'branchaddresszip'}</FromZip5>
<FromZip4/>
<ToName>$shipmentData->{'contactname'}</ToName>
<ToFirm>$shipmentData->{'addressname'}</ToFirm>
<ToAddress1>$shipmentData->{'address2'}</ToAddress1>
<ToAddress2>$shipmentData->{'address1'}</ToAddress2>
<ToCity>$shipmentData->{'addresscity'}</ToCity>
<ToState>$shipmentData->{'addressstate'}</ToState>
<ToZip5>$shipmentData->{'addresszip'}</ToZip5>
<ToZip4/>
<WeightInOunces>$shipmentData->{'weightinounces'}</WeightInOunces>
<ServiceType>$shipmentData->{serviceType}</ServiceType>
<SeparateReceiptPage>True</SeparateReceiptPage>
<ImageType>TIF</ImageType>
<AddressServiceRequested>False</AddressServiceRequested>
<HoldForManifest>N</HoldForManifest>
<Size>$shipmentData->{'packagesize'}</Size>
<Width>$shipmentData->{'dimheight'}</Width>
<Length>$shipmentData->{'dimwidth'}</Length>
<Height>$shipmentData->{'dimlength'}</Height>
<ReturnCommitments>true</ReturnCommitments>
</DeliveryConfirmationV4.0Request>
END

	#$self->log("... XML Request Data:  " . $XML_request);

	return $XML_request;
	}

__PACKAGE__->meta()->make_immutable();

no Moose;

1;

__END__