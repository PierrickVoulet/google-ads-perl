#!/usr/bin/perl -w
#
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
# This example demonstrates how to add a campaign-level bid modifier for
# call interactions.

use strict;
use warnings;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../../lib";
use Google::Ads::GoogleAds::GoogleAdsClient;
use Google::Ads::GoogleAds::Utils::GoogleAdsHelper;
use Google::Ads::GoogleAds::V1::Resources::CampaignBidModifier;
use Google::Ads::GoogleAds::V1::Common::InteractionTypeInfo;
use Google::Ads::GoogleAds::V1::Enums::InteractionTypeEnum qw(CALLS);
use
  Google::Ads::GoogleAds::V1::Services::CampaignBidModifierService::CampaignBidModifierOperation;
use Google::Ads::GoogleAds::V1::Utils::ResourceNames;

use Getopt::Long qw(:config auto_help);
use Pod::Usage;
use Cwd qw(abs_path);

# The following parameter(s) should be provided to run the example. You can
# either specify these by changing the INSERT_XXX_ID_HERE values below, or on
# the command line.
#
# Parameters passed on the command line will override any parameters set in
# code.
#
# Running the example with -h will print the command line usage.
my $customer_id  = "INSERT_CUSTOMER_ID_HERE";
my $campaign_id  = "INSERT_CAMPAIGN_ID_HERE";
my $bid_modifier = "INSERT_BID_MODIFIER_HERE";

sub add_campaign_bid_modifier {
  my ($client, $customer_id, $campaign_id, $bid_modifier) = @_;

  # Create a campaign bid modifier for call interactions with the specified
  # campaign ID and bid modifier value.
  my $campaign_bid_modifier =
    Google::Ads::GoogleAds::V1::Resources::CampaignBidModifier->new({
      campaign => Google::Ads::GoogleAds::V1::Utils::ResourceNames::campaign(
        $customer_id, $campaign_id
      ),
      # Make the bid modifier apply to call interactions.
      interactionType =>
        Google::Ads::GoogleAds::V1::Common::InteractionTypeInfo->new({
          type => CALLS
        }
        ),
      # Set the bid modifier value.
      bidModifier => $bid_modifier
    });

  # Create a campaign bid modifier operation.
  my $campaign_bid_modifier_operation =
    Google::Ads::GoogleAds::V1::Services::CampaignBidModifierService::CampaignBidModifierOperation
    ->new({
      create => $campaign_bid_modifier
    });

  # Add the campaign bid modifier.
  my $campaign_bid_modifier_response =
    $client->CampaignBidModifierService()->mutate({
      customerId => $customer_id,
      operations => [$campaign_bid_modifier_operation]});

  printf "Created campaign bid modifier %s.\n",
    $campaign_bid_modifier_response->{results}[0]{resourceName};

  return 1;
}

# Don't run the example if the file is being included.
if (abs_path($0) ne abs_path(__FILE__)) {
  return 1;
}

# Get Google Ads Client, credentials will be read from ~/googleads.properties.
my $client = Google::Ads::GoogleAds::GoogleAdsClient->new({version => "V1"});

# By default examples are set to die on any server returned fault.
$client->set_die_on_faults(1);

# Parameters passed on the command line will override any parameters set in code.
GetOptions(
  "customer_id=s"  => \$customer_id,
  "campaign_id=i"  => \$campaign_id,
  "bid_modifier=f" => \$bid_modifier
);

# Print the help message if the parameters are not initialized in the code nor
# in the command line.
pod2usage(2) if not check_params($customer_id, $campaign_id, $bid_modifier);

# Call the example.
add_campaign_bid_modifier($client, $customer_id =~ s/-//gr,
  $campaign_id, $bid_modifier);

=pod

=head1 NAME

add_campaign_bid_modifier

=head1 DESCRIPTION

This example demonstrates how to add a campaign-level bid modifier for call interactions.

=head1 SYNOPSIS

add_campaign_bid_modifier.pl [options]

    -help                       Show the help message.
    -customer_id                The Google Ads customer ID.
    -campaign_id                The campaign ID.
    -bid_modifier               The bid modifier value.

=cut
