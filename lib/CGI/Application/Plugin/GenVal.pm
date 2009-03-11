package CGI::Application::Plugin::GenVal;

use strict;
use warnings;
use Carp;

use vars qw ( $VERSION @ISA @EXPORT_OK %EXPORT_TAGS );

require Exporter;
@ISA = qw(Exporter);

@EXPORT_OK = ( 'GenVal' );

%EXPORT_TAGS = (
    all => [ 'GenVal' ],
    std => [ 'GenVal' ],
);

$VERSION = '0.01_01';

my $genval;

sub import {
    ### The real object is in ::guts
    $genval = new CGI::Application::Plugin::GenVal::guts( $_[1] );
    CGI::Application::Plugin::GenVal->export_to_level(1, @_);
}#sub

sub GenVal {
    ### Grab CGI::Application based object and keep a reference to it
    unless ( $genval->{params}->{__ca_obj} ) {
        $genval->{params}->{__ca_obj} = shift;
    }#unless
    return $genval;
}#sub


package CGI::Application::Plugin::GenVal::guts;

use strict;
use warnings;
use Carp;
use Perl6::Junction qw /any/;

### Create simple object
sub new {
    my $class = shift;
    my $obj = {};    
    bless( $obj, $class );
    return $obj;
}#sub


### Method for generating a HTML input tag
sub gen_input {
    my $self = shift;

    ### Make sure they aren't trying to call directly
    croak( "Can only be called as a method" ) unless ( ref( $self ) eq 'CGI::Application::Plugin::GenVal::guts' );

    ### Get CGI::Application based object
    my $ca = $self->{params}->{__ca_obj};
    
    ### Input must be passed in as a single hash reference
    croak( 'Must receive a single hash reference' ) if ( @_ > 1 || ref $_[0] ne 'HASH' );
    
    my $input = shift;
    
    my $inputhtml;

    ### Generate style attribute from input schema
    ### Styles default to {all} then overloaded with style for specific type
    ### values are cloned so as not to effect referenced data
    my $attrib_raw = {};
    if ( $input->{style}->{all}->{ $input->{error}->{type} }->{style} ) {
        _gen_input_addstyle( $attrib_raw, $input->{style}->{all}->{ $input->{error}->{type} }->{style} );
    }#if
    if ( $input->{style}->{ $input->{details}->{type} }->{ $input->{error}->{type} }->{style} ) {
        _gen_input_addstyle( $attrib_raw, $input->{style}->{ $input->{details}->{type} }->{ $input->{error}->{type} }->{style} );
    }#if
    
    ### Create style attribute for CGI.pm HTML generation
    my $attrib_final = _gen_input_tag( $attrib_raw );

    ### Create Text field
    if ( $input->{details}->{type} eq 'text' ) {
        return $ca->query->textfield(
            -name=>$input->{field},
            -value=>$input->{value},
            -size=>$input->{details}->{size},
            -maxlength=>$input->{details}->{max},
            %$attrib_final,
        );
    }#if
    
    ### Create password field
    elsif ( $input->{details}->{type} eq 'password' ) {
        return $ca->query->password_field(
            -name=>$input->{field},
            -value=>$input->{value},
            -size=>$input->{details}->{size},
            -maxlength=>$input->{details}->{max},
            %$attrib_final,
        );
    }#if
    
    ### Create select field
    ### Data for select fields is loaded from a subroutine or method
    elsif ( $input->{details}->{type} eq 'select' ) {
        my ( $labels, $values, $default );
        if ( $input->{details}->{source} =~ /^sub self (.*?)$/ ) {
            eval " ( \$labels, \$values, \$default ) = \$ca->$1( \$input->{value} ); ";
            if ($@) {
                croak( "Error getting values for select '$input->{field}': $@" );
#                $ca->error( $ca->loc( "Error getting values for select '%1': %2", $field, $@ ) );
            }#if
        }#if
        elsif ( $input->{details}->{source} =~ /^sub (.*?)$/ ) {
            eval " ( \$labels, \$values, \$default ) = $1( \$input->{value} ); ";
            if ($@) {
                croak( "Error getting values for select '$input->{field}': $@" );
#                $ca->error( $ca->loc( "Error getting values for select '%1': %2", $field, $@ ) );
            }#if
        }#elsif
        return $ca->query->popup_menu(
            -name=>$input->{field},
            -values=>$values,
            -default=>$default,
            -labels=>$labels,
            %$attrib_final,
        );
    }#if
    
    ### Load custom input HTML field
    ### All HTML for input field comes from a method or subroutine
    ### These are passed the field value and CGI.pm style attributes
    if ( $input->{details}->{type} eq 'custom' ) {
        my $html;
        if ( $input->{details}->{source} =~ /^sub self (.*?)$/ ) {
            eval " \$html = \$ca->$1( \$input->{value}, \$attrib_final ); ";
            if ($@) {
                croak( "Error getting html for custom field '$input->{field}': $@" );
#                $ca->error( $ca->loc( "Error getting html for custom field '$field': $@" ) );
            }#if
        }#if
        elsif ( $input->{details}->{source} =~ /^sub (.*?)$/ ) {
            eval " \$html = $1( \$input->{value}, \$attrib_final ); ";
            if ($@) {
                croak( "Error getting html for custom field '$input->{field}': $@" );
#                $ca->error( $ca->loc( "Error getting html for custom field '$field': $@" ) );
            }#if
        }#elsif
        return $html;
    }#if
}#sub


sub _gen_input_addstyle {
    ### Make sure they aren't trying to call directly
    croak( "Cannot be called directly" ) unless ( caller eq 'CGI::Application::Plugin::GenVal::guts' );

    ### Clone referenced style data from %$list
    my ( $attrib, $list ) = @_;
    while( my ( $key, $value ) = each %$list ) {
        $attrib->{style}->{$key} = $value;
    }#while
}#sub


sub _gen_input_tag {
    ### Make sure they aren't trying to call directly
    croak( "Cannot be called directly" ) unless ( caller eq 'CGI::Application::Plugin::GenVal::guts' );

    ### Create CGI.pm style tag
    my ( $attrib ) = @_;
    my $return = {};
    while( my ( $key, $value ) = each %{ $attrib->{style} } ) {
        $return->{'-style'} .= "$key: $value; "; 
    }#while
    return $return;
}#sub


### Generate DFV (Data::FormValidator) profile for Perl and JavaScript
### Returns both profiles and YAML schema reference
sub gen_dfv {
    my $self = shift;

    ### Make sure they aren't trying to call directly
    croak( "Can only be called as a method" ) unless ( ref( $self ) eq 'CGI::Application::Plugin::GenVal::guts' );

    ### Get CGI::Application based object
    my $ca = $self->{params}->{__ca_obj};

    ### Input must be passed in as a single hash reference
    croak( 'Must receive a single hash reference' ) if ( @_ > 1 || ref $_[0] ne 'HASH' );

    my ( $dfv ) = shift;
    
    ### Some defaults
    $dfv->{prefix} = 'err_' unless $dfv->{prefix};
    $dfv->{any_errors} = 'some_errors' unless $dfv->{any_errors};
    $dfv->{required} = [] unless $dfv->{any_errors};
    
    ### also accepts required, required_hash, constraints_loaded

    ### These two are required
    unless ( $dfv->{schema} ) {
        croak( 'Need input schema' );
    }#unless
    unless ( $dfv->{form} ) {
        croak( 'Need input form' );
    }#unless
    
    ### Load YAML schema from file unless it's passed in
    unless ( ref $dfv->{schema} ) {
        my $capackage = ref $ca;
        if ( defined( &{ "${capackage}::YAML" } ) && ref( $ca->YAML ) eq 'CGI::Application::Plugin::YAML' ) {
            $dfv->{schema} = $ca->YAML->LoadFile( $dfv->{schema} );
        }#if
        else {
            require YAML::Any;
            $dfv->{schema} = YAML::Any::LoadFile( $dfv->{schema} );
        }#else
    }#unless

    ### Make skeleton Perl profile
    my $dfv_profile_perl = {
        required => [],
        optional => [],
        constraint_methods => {},
        msgs => {
            prefix        => $dfv->{prefix},
            any_errors    => $dfv->{any_errors},
            %{ $dfv->{msgs} },
        },
    };

    ### Make skeleton JavaScript profile
    my $dfv_profile_js = {
        required => [],
        optional => [],
        constraints => {},
        msgs => {
            prefix        => $dfv->{prefix},
            any_errors    => $dfv->{any_errors},
            %{ $dfv->{msgs} },
        },
    };

    ### Generate required fields list from schema
    while ( my ($field, $settings) = each ( %{ $dfv->{schema}->{field_input} } ) ) {
        next if ( any( @{ $dfv->{required} } ) eq $field );
        if ( $settings->{required} && lc $settings->{required} ne 'no' ) {
            push( @{ $dfv->{required} }, $field );
        }#if
    }#while

    ### Generate optional fields, also required fields from required_hash
    ### required_hash can either be $hashref->{field}->{required} = 1
    ### or $hashref->{field} = 1
    foreach my $field ( @{ $dfv->{schema}->{ $dfv->{form} } } ) {
        next if ( any( @{ $dfv->{required} } ) eq $field );
        if ( ref $dfv->{required_hash}->{$field} eq 'HASH' ) {
            if ( $dfv->{required_hash}->{$field}->{required} ) {
                push( @{ $dfv->{required} }, $field );
            }#if
            else {
                push( @{ $dfv->{optional} }, $field );
            }#else
        }#if
        else {
            if ( $dfv->{required_hash}->{$field} ) {
                push( @{ $dfv->{required} }, $field );
            }#if
            else {
                push( @{ $dfv->{optional} }, $field );
            }#else
        }#else
    }#foreach
    
    ### Load required and optional into perl and js profiles
    $dfv_profile_perl->{required} = $dfv->{required};
    $dfv_profile_perl->{optional} = $dfv->{optional};
    $dfv_profile_js->{required} = $dfv->{required};
    $dfv_profile_js->{optional} = $dfv->{optional};

    ### Generate constraints
    ### Perl regexps get compiled and put into the new style constraint_methods
    ### JavaScript ones do not
    ### A rough check is done to see if the regexp is JavaScript compatible
    while ( my ($field, $settings) = each ( %{ $dfv->{schema}->{field_input} } ) ) {
        ### Check for array of constraints
        if ( ref $settings->{constraint} eq 'ARRAY' ) {
            foreach my $constraint ( @{ $settings->{constraint} } ) {
                my ( $constraint_perl, $constraint_js );
                ### Check for hash ref
                if ( ref $constraint eq 'HASH' ) {
                    ( $constraint_perl, $constraint_js ) = _gen_dfv_constraints_hash( $dfv, $constraint );
                }#if
                else {
                    ( $constraint_perl, $constraint_js ) = _gen_dfv_constraints( $dfv, $constraint );
                }#else
                ### ??? Do I need to set [] first?
                push( @{ $dfv_profile_perl->{constraint_methods}->{$field} }, $constraint_perl );
                if ( $constraint_js ) {
                    push( @{ $dfv_profile_js->{constraints}->{$field} }, $constraint_js );
                }#if
            }#foreach
        }#if
        ### Check for constraint hash
        elsif ( ref $settings->{constraint} eq 'HASH' ) {
            my ( $constraint_perl, $constraint_js ) = _gen_dfv_constraints_hash( $dfv, $settings->{constraint} );
            $dfv_profile_perl->{constraint_methods}->{$field} = $constraint_perl;
            if ( $constraint_js ) {
                $dfv_profile_js->{constraints}->{$field} = $constraint_js;
            }#if
        }#elsif
        ### Load constraint
        else {
            my ( $constraint_perl, $constraint_js ) = _gen_dfv_constraints( $dfv, $settings->{constraint} );
            $dfv_profile_perl->{constraint_methods}->{$field} = $constraint_perl;
            if ( $constraint_js ) {
                $dfv_profile_js->{constraints}->{$field} = $constraint_js;
            }#if
        }#else
    }#while

    ### Use Data::JavaScript to convert the Perl JS profile to JavaScript code
    require Data::JavaScript;
    unless ( $ca->GenVal->{params}->{__JS_IMPORTED}  ) {
        import Data::JavaScript;
        $ca->GenVal->{params}->{__JS_IMPORTED} = 1;
    }#unless
    
    my $jsprofile = jsdump('dfv_profile', $dfv_profile_js);

    ### Create the JavaScript validation function
    my $jsverify = qq~
    <SCRIPT LANGUAGE="javascript"><!--
    function $dfv->{form}Validate (frmObj) {
        $jsprofile
        var passed = Data.FormValidator.check_and_report(
            frmObj,
            dfv_profile,
            '$dfv->{schema}->{field_input_style}->{all}->{good}->{style}->{background}',
            '$dfv->{schema}->{field_input_style}->{all}->{bad}->{style}->{background}',
            '$dfv->{schema}->{field_input_style}->{all}->{good}->{style}->{'border-color'}',
            '$dfv->{schema}->{field_input_style}->{all}->{bad}->{style}->{'border-color'}',
            'div'
        );
        return passed;
    }
    // --></SCRIPT>\n~;
    
    return ( $dfv_profile_perl, $jsverify, $dfv->{schema} );
}#sub


### Generate dfv constraints
sub _gen_dfv_constraints {
    ### Make sure they aren't trying to call directly
    croak( "Cannot be called directly" ) unless ( caller eq 'CGI::Application::Plugin::GenVal::guts' );

    my ( $dfv, $constraint ) = @_;
    my ( $return_perl, $return_js );

    ### Create subroutine references for Perl profile
    ## JS doesn't support this
    if ( $constraint =~ /^subref (.*?)$/ ) {
        $return_perl = \&{$1};
    }#if

    ### Create methods
    elsif ( $constraint =~ /^method (.*?)$/ ) {
        my $method = $1;
        my $methodname;
        if ( $method =~ /^([a-z0-9_]*)?\(/i ) {
            $methodname = $1;
        }#if
        else {
            $methodname = $method;
        }#else
        
        ### Load constraint methods from DFV::Constraints
        unless ( $dfv->{constraints_loaded}->{$methodname} ) {
            require Data::FormValidator::Constraints;
            if ( any( @Data::FormValidator::Constraints::EXPORT_OK ) eq $methodname ) {
                Data::FormValidator::Constraints->import( $methodname );
            }#if
            $dfv->{constraints_loaded}->{$methodname} = 1;
        }#unless

        ### Load straight into Perl profile
        my $evaltext = qq~\$return_perl = $method;~;
        eval $evaltext;
        die( "Error loading constraint method $method: $@" ) if $@;

        ### Extract paramater for conversion to JS
        ### New style DFV methods are converted to old style ones for JavaScript
        if ( $method =~ /^(.*)?\(\s?(.+?)\s?\)$/ ) {
            my $methodname = $1;
            my $params = $2;
            eval "\$params = [$params];";
            die( "Error loading constraint params $params: $@" ) if $@;
            ### Remove FV_ from start of name
            my $name = $methodname;
            $name =~ s/^FV_//i;
            $return_js = {
                constraint => $methodname,
                params     => $params,
                name       => $name,
            };
        }#if
        else {
            $method =~ s/[\(\)]//g;
            $return_js = $method;
        }#else
    }#elsif

    ### Create regexps
    ### Js compatible
    elsif ( $constraint =~ m#^/.*?/i?$# ) {
        ### Compile regexp into Perl profile
        my $evaltext = qq~\$return_perl = qr$constraint;~;
        eval $evaltext;
        die( "Error compiling regexp $constraint: $@" ) if $@;
        ### Pass to JS
        $return_js = $constraint;
    }#elsif

    ### Perl only
    elsif ( $constraint =~ m#^/.*?/[sixm]*$# ) {
        ### Compile regexp into Perl profile
        my $evaltext = qq~\$return_perl = qr$constraint;~;
        eval $evaltext;
        die( "Error compiling regexp $constraint: $@" ) if $@;
    }#elsif
    return ( $return_perl, $return_js );
}#sub


### Generate contraints from a hash with contraint details
sub _gen_dfv_constraints_hash {
    ### Make sure they aren't trying to call directly
    croak( "Cannot be called directly" ) unless ( caller eq 'CGI::Application::Plugin::GenVal::guts' );

    my ( $dfv, $constraint ) = @_;
    
    ### Prepare return variables
    my ( $return_perl, $return_js ) = ( {}, {} );
    
    ### Generate constraint from {constraint} key
    my ( $constraint_perl, $constraint_js ) = _gen_dfv_constraints( $dfv, $constraint->{constraint} );
    $return_perl->{constraint_method} = $constraint_perl;
    if ( $constraint_js ) {
        $return_js = $constraint_js;
    }#if
    
    ### Copy additional contraint details
    while ( my ($key, $value) = each ( %$constraint ) ) {
        next if ( $key eq 'constraint' );
        $return_perl->{$key} = $value;
        if ( $return_js->{constraint} ) {
            $return_js->{$key} = $value;
        }#if
    }#while
    $return_js = undef unless ( keys %$return_js );
    return ( $return_perl, $return_js );
}#sub


1;

__END__

=head1 NAME

CGI::Application::Plugin::GenVal - Generate input forms with client/server
validation

=head1 DESCRIPTION

This module aims to make the tricky task of setting up forms with accompanying 
client/server side validation much simpler. Once setup rather than editing HTML,
javascript and perl all you need to do is edit one central YAML file.
It uses Data::Formvalidator and a modified version of Data.FormValidator.js. It
also utilizes CGI::Application::Plugin::YAML if available, otherwise loads
YAML::Any.
Newer versions of Data::FormValidator use compiled regexps and new style
contraint methods. This broke compatibility when converting the profile to
JavaScript. This module fixes that issue by having the constraints in YAML
which are then compiled into the new format for Data::FormValidator and
converted to the old format for Data.FormValidator.js. Allowing you to get the
best from both worlds.

B<This is alpha, anything could change dramatically!!!>

=head1 SYNOPSIS

This module allows you to consolidate your form generation, client and server
side validation into a central YAML schema file.

    use CGI::Application::Plugin::GenVal qw( :std );

Create Data::FormValidator Perl and JavaScript profiles, return YAML schema:-

    ( $dfv_profile, $js_profile, $yaml_schema ) = $self->GenVal->gen_dfv( {
            schema => 'formschema.yml.pl',
            form   => 'form1',
            required_hash => { 'field_name_1' => 1, 'field_name_2' => 1 },
            required => [ 'field_name_3', 'field_name_3' ],
            msgs => {
                missing       => 'Required',
                invalid       => 'Invalid',
                constraints   => {
                    'eq_with' => 'Must match',
                },
            },
        } );

Generate input field:-

    $self->GenVal->gen_input( {
            field => $field,
            value => $value,
            details => $yaml_schema->{field_input}->{$field},
            style => $yaml_schema->{field_input_style},
            error => { type => 'good' },
        } );

Example code...
In YAML file:-

    ---
    field_text:
      name: Name
      website: Website
      email: Email
      email-confirm: Confirm Email
      phone: Phone Number
    field_input:
      name:
        max: 24
        size: 30
        type: text
        constraint: /^(?:[\w\- \,\.]*){0,24}$/
        required: yes
      website:
        max: 128
        size: 134
        type: text
        constraint: /^https?:\/\/[\w\- .]*$/
        required: no
      email:
        max: 64
        size: 70
        type: text
        required: yes
        constraint:
        - /^(([a-z0-9_\.\+\-\=\?\^\#]){1,64}\@(([a-z0-9\-]){1,251}\.){1,252}[a-z0-9]{2,4})$/i
        - constraint: method FV_eq_with('email-confirm')
      email-confirm:
        max: 64
        size: 70
        type: text
        required: yes
        constraint:
        - /^(([a-z0-9_\.\+\-\=\?\^\#]){1,64}\@(([a-z0-9\-]){1,251}\.){1,252}[a-z0-9]{2,4})$/i
        - constraint: method FV_eq_with('email')
      phone:
        max: 20
        size: 26
        type: text
        constraint: /^[0-9 \-\+\(\)]*$/i
        required: no
    field_input_style:
      all:
        normal:
          style:
            background: '#cdffbe'
            border: '1px solid #28bc40'
            border-color: '#009d16 #00e921 #00e921 #009d16'
        good:
          style:
            background: '#cdffbe'
            border: '1px solid #28bc40'
            border-color: '#009d16 #00e921 #00e921 #009d16'
        bad:
          style:
            background: '#ffbebe'
            border: '1px solid #d81f1f'
            border-color: '#940000 #e20404 #e20404 #940000'
    signup:
      name
      website
      email
      email-confirm
      phone

In HTML Template:-

    <form action="cgiapp.cgi" method="post" onSubmit="return signupValidate(this);" name=signup>
        <input type=hidden name=rm value="processform" />
        <table border=0 cellpadding=4 cellspacing=0>
            <tmpl_loop name=signup_fields>
                <tr>
                    <td>
                        <tmpl_if name=field_required><b>*</b></tmpl_if>
                        <tmpl_var name=field_text>
                        <div id="error_<tmpl_var name=field_name>">
                            <b><tmpl_var name=field_error></b>
                        </div>
                    </td>
                    <td><tmpl_var name=field_input></td>
                </tr>
            </tmpl_loop>
        </table>
        <input type=submit name=submit value="Submit" />
    </form>

In your CGI::Application runmode:-

    use Data::FormValidator;
    
    ### Display and process form
    sub processform {
        my $self = shift;

        ### Load dfv profiles and schema
        my ( $dfv_profile, $js_profile, $yaml_schema ) = $self->GenVal->gen_dfv( {
            schema => 'signup.yml.pl',
            form   => 'signup',
            msgs => {
                missing       => 'Required',
                invalid       => 'Invalid',
                constraints   => {
                    'eq_with' => 'Must match',
                },
            },
        } );

        ### Check if we've received data and validate
        my $errorhash;
        if ( $self->query->param( 'submit' ) ) {
            my $results = Data::FormValidator->check( $self->query, $dfv_profile );
            
            ### get error details
            $errorhash = $results->msgs;
            
            ### Forword to next runmode if no errors
            unless ( keys %$errorhash ) {
                return $self->forward('saveform');
            }#else
        }#if

        ### Prepare form input field style
        my $errordetails = {
            type => 'normal',
        };

        ### Loop through fields for this form
        my @signup_fields;
        foreach my $field ( @{ $yaml_schema->{signup} } ) {

            ### Style fields to good or bad if input did not validate
            if ( $errorhash ) {
                if ( $errorhash->{"err_$field"} ) {
                    $errordetails = {
                        type => 'bad',
                        text => $errorhash->{"err_$field"},
                    };
                }#if
                else {
                    $errordetails->{type} = 'good';
                }#else
            }#if

            ### Fix required for tmpl_if
            ### Needed because we allow people to set required to 'no'
            my $required = 0;
            if ( $yaml_schema->{field_input}->{$field}->{required} && lc( $yaml_schema->{field_input}->{$field}->{required} ) ne 'no' ) {
                $required = 1;
            }#if

            ### Generate input field and prepare for template
            my $value = $self->query->param( $field );
            push( @signup_fields, {
                field_name     => $field,
                field_required => $required,
                field_text     => $yaml_schema->{field_text}->{$field},
                field_error    => $errorhash->{"err_$field"},
                field_input    => $self->GenVal->gen_input(
                    $field,
                    $value,
                    $yaml_schema->{field_input}->{$field},
                    $yaml_schema->{field_input_style},
                    $errordetails,
                ),
            });
        }#foreach
        
        my $template = $self->load_tmpl( 'form.html', die_on_bad_params => 0 );
        $template->param(
            {
                js_profile        => $js_profile,
                signup_fields     => \@signup_fields,
            }
        );
    
        return $template->output();
    }#sub

=head1 Object

=head2 GenVal

This is the only method returned. It is in fact an object with the following
methods.

=head1 Methods

=head2 gen_input

This method generates the input fields. The following describes it's input
parameters which must be passed in as a hash reference.

=head3 style

The fields can have different styles,
such as C<normal> (used the first time form is displayed), C<good> (if the input
value validated) and C<bad> (if the input value failed validation). These styles
can be applied to specific field types, or as the default for all field types by
defining a key called C<all>.
The C<style> parameter should be passed in as a hash reference in the format:-

    $style = {
        all => {
            normal => {
                style => {
                    background   => '#cdffbe',
                    border       => '1px solid #28bc40',
                    border-color => '#009d16 #00e921 #00e921 #009d16',
                },
            },
            good => {
                style => {
                    background   => '#cdffbe',
                    border       => '1px solid #28bc40',
                    border-color => '#009d16 #00e921 #00e921 #009d16',
                },
            },
            bad => {
                style => {
                    background   => '#ffbebe',
                    border       => '1px solid #d81f1f',
                    border-color => '#940000 #e20404 #e20404 #940000',
                },
            },
        },
        select => { ### Overload 'all' defaults for 'select' field types
            normal => {
                style => {
                    background   => '#ffffff',
                },
            },
    };

This is usually stored in your YAML schema rather than your Perl code.

    field_input_style:
      all:
        normal:
          style:
            background: '#cdffbe'
            border: '1px solid #28bc40'
            border-color: '#009d16 #00e921 #00e921 #009d16'
        good:
          style:
            background: '#cdffbe'
            border: '1px solid #28bc40'
            border-color: '#009d16 #00e921 #00e921 #009d16'
        bad:
          style:
            background: '#ffbebe'
            border: '1px solid #d81f1f'
            border-color: '#940000 #e20404 #e20404 #940000'
      select:
        normal:
          style:
            background: '#ffffff'

=head3 field

This is the field name

=head3 value

This is the field value (if any)

=head3 details

You must define the details of your form field, such as type, size, etc. The
details parameter must be a hash reference with keys of
C<type> (values text, password, select, custom)
C<max> (used for text and password field types)
C<size> (field display size)
C<source> (data source for some types).

These are generally stored in your YAML schema:-

    field_input:
      name:
        max: 24
        size: 30
        type: text
        constraint: /^(?:[\w\- \,\.]*){0,24}$/
        required: yes
      website:
        max: 128
        size: 134
        type: text
        constraint: /^https?:\/\/[\w\- .]*$/
        required: no

Notice how the schema includes extra keys for constraint and required. They are
not used here, but do not cause any problems.

For C<select> field types, you must provide a data source. This is passed in
C<value>, and expected to return a hash reference of labels (key being the
option value, value being the option label), an array reference of option values
(to get the order) and scalar of the default value. The source must be defined
as a string in the form:-

    source => 'sub self SUBNAME', ### Object method

Or

    source => 'sub SUBNAME', ### Subroutine

Which are translated to:-

    ( $labels, $values, $default ) = $self->SUBNAME( $value );

And

    ( $labels, $values, $default ) = SUBNAME( $value );

For C<custom> field types, you must also provide a data source. This is passed
in C<value> and a CGI.pm style tag attribute. It's expected to return the HTML
for the form field. The source must be defined as a string in the form:-

    source => 'sub self SUBNAME', ### Object method

Or

    source => 'sub SUBNAME', ### Subroutine

Which are translated to:-

    $html = $self->SUBNAME( $value, $style );

And

    $html = SUBNAME( $value );

Examples in YAML:-

    field_input:
      month:
        type: select
        source: sub self month_select
        constraint: /^[\w]*$/
      timezone:
        type: custom
        source: sub create_timezones
        required: yes
        constraint: /^[\w\-\/]*$/

=head3 error

This parameter is used to define the style used, and provide any error text. It
must be a hash reference with keys
C<type> to match the style type (normal, good, bad)
C<text> the error message if any

    $errorhash = {
        type => 'normal'
    };

    $errorhash = {
        type => 'bad',
        text => 'Field required',
    };

=head2 gen_dfv

This method generates the DFV profiles for Perl and JavaScript from YAML schema.
It returns both profiles and the YAML schema. The YAML schema can be passed in,
or you can pass a filename instead. The following describes it's input
parameters which must be passed in as a hash reference.

=head3 prefix

Set a prefix for field error messages. This is the same as DFV {msgs}->{prefix}.
Defaults to 'err_' to make 'err_FIELDNAME' => 'Required', etc.

=head3 any_errors

Sets a flag in the results if any errors were returned. Same as DFV
{msgs}->{any_errors}. Defaults to 'some_errors'.

=head3 required

List of required fields. Defaults to empty. This list is added to from the
YAML schema field_input settings.

=head3 required_hash

Hash reference of required fields. This is useful if you have your required
fields defined by a configuration file. Can be in the form:-

    {required_hash}->{fieldname}->{required} = 1;

or

    {required_hash}->{fieldname} = 1;

=head3 constraints_loaded

Hash list of constrant methods from Data::FormValidator::Constraints that have
already been loaded. This is useful if you have multiple forms to save
importing them again.

=head3 schema

This is either your pre-loaded YAML schema, or the file location. Such as:-

    {schema} => $LoadedYAML,

or

    {schema} => 'myform.yml.pl',

Schema must be in the format:-

    ---
    field_text:
      FIELDNAME: DESCRIPTION
      FIELDNAME2: DESCRIPTION2
    field_input:
      FIELDNAME:
        constraint: /^(?:[\w\- \,\.]*){0,24}$/
        required: yes
      FIELDNAME2:
        constraint: /^https?:\/\/[\w\- .]*$/
        required: no
    FORMNAME:
      FIELDNAME
      FIELDNAME2

You must have a key called field_input that contains a hash of the fieldnames,
which in turn contain a hash of the constraint and if the field is required.
The FORMNAME list if used to generate the optional fields for this form.

=head3 form

The name of this form (required). Naming the form allows you to have multiple
forms on the same page.

=head3 msgs

This is simply passed through to the DFV {msgs} key. If you set
{msgs}->{prefix} or {msgs}->{any_errors} they will override the {prefix} and
{any_errors} described above.

=head3 About Constraints

Newer versions of Data::FormValidator use compiled regexps and new style
contraint methods. This broke compatibility when converting the profile to
JavaScript. This module fixes that issue by having the constraints in YAML
which are then compiled into the new format for Data::FormValidator and
converted to the old format for Data.FormValidator.js. Allowing you to get the
best from both worlds.

All constraints must be in a key called 'constraint'. This is loaded to
'constraint_methods' for Perl and 'constraints' for JavaScript.

You can define multiple constraints by having the 'constraint' key point to an
array, such as:-

    field_input:
      FIELDNAME:
        constraint:
        - /^[a-z]*$/i
        - /^[A-C]*$/

This would generate Perl of:-

    $dfv->{constraint_methods}->{FIELDNAME} = [
        qr/^[a-z]*$/i
        qr/^[A-C]*$/
    ];

JavaScript of (well perl version of javascript):-

    $dfv->{constraints}->{FIELDNAME} = [
        '/^[a-z]*$/i'
        '/^[A-C]*$/'
    ];

If JavaScript doesn't support the regexp such as those ending in or /s or /x,
then the constraint isn't loaded into JavaScript:-

    field_input:
      FIELDNAME:
        constraint:
        - /^[a-z]*$/i
        - /^[A-C]*$/s

This would generate Perl of:-

    $dfv->{constraint_methods}->{FIELDNAME} = [
        qr/^[a-z]*$/i
        qr/^[A-C]*$/s
    ];

JavaScript of (well perl version of javascript):-

    $dfv->{constraints}->{FIELDNAME} = '/^[a-z]*$/i';

You can also use the new DFV built in methods, such as FV_eq_with. This is
downgraded to an old style version for JavaScript:-

    field_input:
      email:
        required: yes
        constraint:
        - /^(([a-z0-9_\.\+\-\=\?\^\#]){1,64}\@(([a-z0-9\-]){1,251}\.){1,252}[a-z0-9]{2,4})$/i
        - constraint: method FV_eq_with('email-confirm')
      email-confirm:
        required: yes
        constraint:
        - /^(([a-z0-9_\.\+\-\=\?\^\#]){1,64}\@(([a-z0-9\-]){1,251}\.){1,252}[a-z0-9]{2,4})$/i
        - constraint: method FV_eq_with('email')

This would generate Perl of:-

    $dfv->{constraint_methods} =
        'email' => [
            qr/^(([a-z0-9_\.\+\-\=\?\^\#]){1,64}\@(([a-z0-9\-]){1,251}\.){1,252}[a-z0-9]{2,4})$/i,
            \&FV_eq_with( 'email-confirm' ), ### Similar, FV_eq_with actually returns a subroutine
        ],
        'email-confirm' => [
            qr/^(([a-z0-9_\.\+\-\=\?\^\#]){1,64}\@(([a-z0-9\-]){1,251}\.){1,252}[a-z0-9]{2,4})$/i,
            \&FV_eq_with( 'email' ), ### Similar, FV_eq_with actually returns a subroutine
        ],

JavaScript of (well perl version of javascript):-

    $dfv->{constraints} =
        'email' => [
            '/^(([a-z0-9_\.\+\-\=\?\^\#]){1,64}\@(([a-z0-9\-]){1,251}\.){1,252}[a-z0-9]{2,4})$/i',
            {
                constraint => 'FV_eq_with',
                params => [ 'email-confirm' ],
                name => 'eq_with',
            },
        ],
        'email-confirm' => [
            qr/^(([a-z0-9_\.\+\-\=\?\^\#]){1,64}\@(([a-z0-9\-]){1,251}\.){1,252}[a-z0-9]{2,4})$/i,
            {
                constraint => 'FV_eq_with',
                params => [ 'email' ],
                name => 'eq_with',
            },
        ],

=head3 About JavaScript

The returned JavaScript code includes a function named 'formValidate' (where
form is form name) encased in a E<lt>SCRIPTE<gt> tag ready to be parsed into your
HTML page. You also need to update your E<lt>FORME<gt> tag to include:-

    onSubmit="return formValidate(this);"

Such as:-

    <form action="cgiapp.cgi" method="post" onSubmit="return formnameValidate(this);" name=formname>

=head1 Export groups

Only an object called GenVal is exported. 

:all exports:-

    GenVal

:std exports:-

    GenVal

=head1 Thanks to:-

L<Data::FormValidator>

=head1 Come join the bestest Perl group in the World!

Bristol and Bath Perl moungers is renowned for being the friendliest Perl group
in the world. You don't have to be from the UK to join, everyone is welcome on
the list:-
L<http://perl.bristolbath.org>

=head1 AUTHOR

Lyle Hopkins ;)

=cut
