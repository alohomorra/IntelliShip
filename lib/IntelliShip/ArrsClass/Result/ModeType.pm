use utf8;
package IntelliShip::ArrsClass::Result::ModeType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

IntelliShip::ArrsClass::Result::ModeType

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=item * L<DBIx::Class::TimeStamp>

=item * L<DBIx::Class::PassphraseColumn>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime", "TimeStamp", "PassphraseColumn");

=head1 TABLE: C<modetype>

=cut

__PACKAGE__->table("modetype");

=head1 ACCESSORS

=head2 modetypeid

  data_type: 'integer'
  is_nullable: 0

=head2 mode

  data_type: 'varchar'
  is_nullable: 0
  size: 50

=cut

__PACKAGE__->add_columns(
  "modetypeid",
  { data_type => "integer", is_nullable => 0 },
  "mode",
  { data_type => "varchar", is_nullable => 0, size => 50 },
);

=head1 PRIMARY KEY

=over 4

=item * L</modetypeid>

=back

=cut

__PACKAGE__->set_primary_key("modetypeid");


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2013-11-20 04:13:49
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:p7rFapeTO/2USzYi088nJg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
