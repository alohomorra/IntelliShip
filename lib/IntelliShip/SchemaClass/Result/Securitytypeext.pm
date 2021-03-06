use utf8;
package IntelliShip::SchemaClass::Result::Securitytypeext;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

IntelliShip::SchemaClass::Result::Securitytypeext

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

=head1 TABLE: C<securitytypeext>

=cut

__PACKAGE__->table("securitytypeext");

=head1 ACCESSORS

=head2 securitytypeext

  data_type: 'varchar'
  is_nullable: 0
  size: 35

=head2 customerid

  data_type: 'char'
  is_nullable: 0
  size: 13

=head2 securitytypeid

  data_type: 'integer'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "securitytypeext",
  { data_type => "varchar", is_nullable => 0, size => 35 },
  "customerid",
  { data_type => "char", is_nullable => 0, size => 13 },
  "securitytypeid",
  { data_type => "integer", is_nullable => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07039 @ 2014-02-26 01:20:35
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:assv5NK7SfsV/7Zs8BS+SA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
