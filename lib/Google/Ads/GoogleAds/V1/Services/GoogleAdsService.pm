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

package Google::Ads::GoogleAds::V1::Services::GoogleAdsService;

use strict;
use warnings;
use base qw(Google::Ads::GoogleAds::BaseService);

sub mutate {
  my $self         = shift;
  my $request_body = shift;
  my $http_method  = 'POST';
  my $response_type =
'Google::Ads::GoogleAds::V1::Services::GoogleAdsService::MutateGoogleAdsResponse';
  my $request_path = 'v1/customers/{+customerId}/googleAds:mutate';

  return $self->SUPER::call($http_method, $request_path, undef, $request_body,
    $response_type);
}

sub search {
  my $self         = shift;
  my $request_body = shift;
  my $http_method  = 'POST';
  my $response_type =
'Google::Ads::GoogleAds::V1::Services::GoogleAdsService::SearchGoogleAdsResponse';
  my $request_path = 'v1/customers/{+customerId}/googleAds:search';

  return $self->SUPER::call($http_method, $request_path, undef, $request_body,
    $response_type);
}

1;
