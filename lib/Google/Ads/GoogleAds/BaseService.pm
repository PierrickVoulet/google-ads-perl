# Copyright 2019, Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# The base class for all Google Ads API services, e.g. CampaignService,
# AdGroupService, etc.

package Google::Ads::GoogleAds::BaseService;

use strict;
use warnings;
use version;

# The following needs to be on one line because CPAN uses a particularly hacky
# eval() to determine module versions.
use Google::Ads::GoogleAds::Constants; our $VERSION = ${Google::Ads::GoogleAds::Constants::VERSION};
use Google::Ads::GoogleAds::Logging::GoogleAdsLogger;
use Google::Ads::GoogleAds::Utils::GoogleAdsHelper;
use Google::Ads::GoogleAds::GoogleAdsException;

use Class::Std::Fast;
use LWP::UserAgent;
use JSON::XS;
use URI::Query;
use utf8;

# Class::Std-style attributes. Need to be kept in the same line.
# These need to go in the same line for older Perl interpreters to understand.
my %api_client_of : ATTR(:name<api_client> :default<>);
my %__user_agent_of : ATTR(:name<__user_agent> :default<>);
my %__json_coder_of : ATTR(:name<__json_coder> :default<>);

# Automatically called by Class::Std after the values for all the attributes
# have been populated but before the constructor returns the new object.
sub START {
  my ($self, $ident) = @_;

  $__user_agent_of{$ident} ||= LWP::UserAgent->new();
  # The 'pretty' attribute should be enabled for more readable form in the log.
  # The 'convert_blessed' attributed should be enabled to convert blessed objects.
  $__json_coder_of{$ident} ||= JSON::XS->new->utf8->pretty->convert_blessed;
}

# Sends a HTTP request to Google Ads API server and handles the response.
sub call {
  my (
    $self,        $http_method,  $request_path,
    $path_params, $request_body, $response_type
  ) = @_;

  my $api_client = $self->get_api_client();

  # GET/POST: If the $path_params argument is present, use it to expand
  # the {+resourceName} or any other expression in the request path.
  if ($path_params) {
    if (not ref $path_params) {
      # When the $path_params argument is a scalar. e.g.
      #
      #  GET:  'v2/{+resourceName}'
      #  POST: 'v2/{+keywordPlan}:generateForecastMetrics'
      #  POST: 'v2/{+campaignDraft}:promote'
      #  POST: 'v1/{+resourceName}:addOperations'
      #
      $request_path = expand_path_template($request_path, $path_params);
    } else {
      # When the $path_params argument is a hash reference, use the value for
      # 'resourceName' key to expand if it exists, and add all the other
      # key-value pairs to URL query parameters. e.g.
      #
      #  GET: CampaignExperimentService.list_async_errors
      #  GET: CampaignDraftService.list_async_errors
      #  GET: MutateJobService.list_results
      #
      $request_path =
        expand_path_template($request_path, delete $path_params->{resourceName})
        if $path_params->{resourceName};

      my $url_query = URI::Query->new($path_params);
      $request_path .= ("?" . $url_query) if $url_query;
    }
  }

  # POST: If the 'customer_id' key in the $request_body argument is present, use
  # its value to expand the {+customerId} expression in the request path.
  $request_path =
    expand_path_template($request_path, $request_body->{customerId})
    if $request_body and $request_body->{customerId};

  # Generate the request URL from the API service address and the request path.
  my $request_url = $api_client->get_service_address() . $request_path;

  my $json_coder = $self->get___json_coder();

  # Encode the JSON request content for POST request.
  my $request_content = undef;
  if ($http_method eq 'POST') {
    $request_content =
      defined $request_body
      ? $json_coder->encode($request_body)
      : '{}';
  }

  my $auth_handler = $api_client->_get_auth_handler();
  if (!$auth_handler) {
    $api_client->get_die_on_faults()
      ? die(Google::Ads::GoogleAds::Constants::NO_AUTH_HANDLER_SETUP_MESSAGE)
      : warn(Google::Ads::GoogleAds::Constants::NO_AUTH_HANDLER_SETUP_MESSAGE);
    return;
  }

  my $http_headers = $self->_get_http_headers();
  my $http_request =
    $auth_handler->prepare_request($http_method, $request_url, $http_headers,
    $request_content);

  utf8::is_utf8 $http_request and utf8::encode $http_request;

  my $user_agent = $self->get___user_agent();

  # Set up timeout and proxy for the user agent.
  $user_agent->timeout(Google::Ads::GoogleAds::Constants::DEFAULT_LWP_TIMEOUT);
  my $proxy = $api_client->get_proxy();
  $proxy
    ? $user_agent->proxy(['http', 'https'], $proxy)
    : $user_agent->env_proxy;

  my $http_response = $user_agent->request($http_request);

  my $response_content = $http_response->decoded_content;

  # Log the one-line summary and the traffic detail. Error may occur when the
  # response content is not in JSON format.
  eval {
    Google::Ads::GoogleAds::Logging::GoogleAdsLogger::log_summary($http_request,
      $http_response);
    Google::Ads::GoogleAds::Logging::GoogleAdsLogger::log_detail($http_request,
      $http_response);
  };
  if ($@) {
    $api_client->get_die_on_faults()
      ? die($response_content . "\n")
      : warn($response_content . "\n");
    return;
  }

  my $json_response = $json_coder->decode($response_content);

  if ($http_response->is_success) {
    # Bless the JSON format response to the response type class.
    bless $json_response, $response_type if $response_type;
    return $json_response;
  } else {
    $api_client->get_die_on_faults()
      ? die($response_content)
      : warn($response_content);

    return Google::Ads::GoogleAds::GoogleAdsException->new($json_response);
  }
}

# Protected method to generate the appropriate REST request headers.
sub _get_http_headers {
  my ($self) = @_;

  my $api_client = $self->get_api_client();

  my $headers = [
    "Content-Type",
    "application/json; charset=utf-8",
    "user-agent",
    Google::Ads::GoogleAds::Constants::DEFAULT_USER_AGENT,
    "x-goog-api-client",
    Google::Ads::GoogleAds::Constants::DEFAULT_USER_AGENT,
    "developer-token",
    $api_client->get_developer_token()];

  my $login_customer_id = $api_client->get_login_customer_id();
  push @$headers, ("login-customer-id", $login_customer_id =~ s/-//gr)
    if $login_customer_id;

  return $headers;
}

1;

=pod

=head1 NAME

Google::Ads::GoogleAds::BaseService

=head1 DESCRIPTION

The abstract base class for all Google Ads API services, e.g. CampaignService,
AdGroupService, etc.

=head1 SYNOPSIS

  use Google::Ads::GoogleAds::GoogleAdsClient;

  my $api_client = Google::Ads::GoogleAds::GoogleAdsClient->new({version => "V1"});

  my $campaign_service = $api_client->CampaignService();

=head1 ATTRIBUTES

Each service instance is initialized by L<Google::Ads::GoogleAds::GoogleAdsClient>,
and these attributes are set automatically.

Alternatively, there is a get_ and set_ method associated with each attribute
for retrieving or setting them dynamically.

  my %api_client_of : ATTR(:name<api_client> :default<>);

=head2 api_client

A reference to the L<Google::Ads::GoogleAds::GoogleAdsClient>, holding the API
credentials and configurations.

=head1 METHODS

=head2 call

Sends REST HTTP requests to Google Ads API server and handles the responses.

=head3 Parameters

=over

=item *

I<http_method>: The HTTP request method, e.g. GET, POST.

=item *

I<request_path>: The relative request URL which may contains wildcard to expand,
e.g. {+resourceName}, {+customerId}.

=item *

I<path_params>: The parameter(s) to expand the {+resourceName} or any other
expression in the request path, which might be a scalar or a hash reference.

=item *

I<request_body>: A Perl object representing the HTTP request payload, which will
be encoded into JSON string for a HTTP POST request. Should be C<undef> for GET request.

=item *

I<response_type>: The class name of the expected response. A instance of this class
will be returned if the request succeeds.

=back

=head3 Returns

A instance of the class defined by the C<response_type> argument, or a
L<Google::Ads::GoogleAds::GoogleAdsException> object if an error has occurred at the
server side by default. However if the C<die_on_faults> flag is set to true in
L<Google::Ads::GoogleAds::GoogleAdsClient>, the service will issue a die() with error
message on API errors.

=head2 _get_http_headers

Prepare the basic HTTP request headers including Content-Type, developer-token and
login_customer_id - if needed. The headers will be consolidated with access token
in the method of L<Google::Ads::GoogleAds::Common::OAuth2BaseHandler/prepare_request>.

=head3 Returns

The basic HTTP headers including Content-Type, developer-token and login_customer_id
- if needed.

=cut

=head1 LICENSE AND COPYRIGHT

Copyright 2019 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 REPOSITORY INFORMATION

 $Rev: $
 $LastChangedBy: $
 $Id: $

=cut
