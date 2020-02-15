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
# This example creates a shopping campaign associated with an existing
# merchant center account, along with a related ad group and dynamic
# display ad, and targets a user list for remarketing purposes.

use strict;
use warnings;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../../lib";
use Google::Ads::GoogleAds::Client;
use Google::Ads::GoogleAds::Utils::GoogleAdsHelper;
use Google::Ads::GoogleAds::Utils::MediaUtils;
use Google::Ads::GoogleAds::V2::Resources::Campaign;
use Google::Ads::GoogleAds::V2::Resources::ShoppingSetting;
use Google::Ads::GoogleAds::V2::Resources::AdGroup;
use Google::Ads::GoogleAds::V2::Resources::AdGroupAd;
use Google::Ads::GoogleAds::V2::Resources::Ad;
use Google::Ads::GoogleAds::V2::Resources::Asset;
use Google::Ads::GoogleAds::V2::Resources::AdGroupCriterion;
use Google::Ads::GoogleAds::V2::Common::ManualCpc;
use Google::Ads::GoogleAds::V2::Common::ResponsiveDisplayAdInfo;
use Google::Ads::GoogleAds::V2::Common::AdImageAsset;
use Google::Ads::GoogleAds::V2::Common::AdTextAsset;
use Google::Ads::GoogleAds::V2::Common::ImageAsset;
use Google::Ads::GoogleAds::V2::Common::UserListInfo;
use Google::Ads::GoogleAds::V2::Enums::AdvertisingChannelTypeEnum qw(DISPLAY);
use Google::Ads::GoogleAds::V2::Enums::CampaignStatusEnum;
use Google::Ads::GoogleAds::V2::Enums::AdGroupStatusEnum;
use Google::Ads::GoogleAds::V2::Enums::AssetTypeEnum qw(IMAGE);
use Google::Ads::GoogleAds::V2::Services::CampaignService::CampaignOperation;
use Google::Ads::GoogleAds::V2::Services::AdGroupService::AdGroupOperation;
use Google::Ads::GoogleAds::V2::Services::AdGroupAdService::AdGroupAdOperation;
use Google::Ads::GoogleAds::V2::Services::AssetService::AssetOperation;
use
  Google::Ads::GoogleAds::V2::Services::AdGroupCriterionService::AdGroupCriterionOperation;
use Google::Ads::GoogleAds::V2::Utils::ResourceNames;

use Getopt::Long qw(:config auto_help);
use Pod::Usage;
use Cwd qw(abs_path);
use Data::Uniqid qw(uniqid);

# The following parameter(s) should be provided to run the example. You can
# either specify these by changing the INSERT_XXX_ID_HERE values below, or on
# the command line.
#
# Parameters passed on the command line will override any parameters set in
# code.
#
# Running the example with -h will print the command line usage.
my $customer_id        = "INSERT_CUSTOMER_ID_HERE";
my $merchant_center_id = "INSERT_MERCHANT_CENTER_ID_HERE";
my $campaign_budget_id = "INSERT_CAMPAIGN_BUDGET_ID_HERE";
my $user_list_id       = "INSERT_USER_LIST_ID_HERE";

sub add_merchant_center_dynamic_remarketing_campaign {
  my ($api_client, $customer_id, $merchant_center_id, $campaign_budget_id,
    $user_list_id)
    = @_;

  # Create a shopping campaign associated with a given merchant center account.
  my $campaign_resource_name =
    create_campaign($api_client, $customer_id, $merchant_center_id,
    $campaign_budget_id);

  # Create an ad group for the campaign.
  my $ad_group_resource_name =
    create_ad_group($api_client, $customer_id, $campaign_resource_name);

  # Create a dynamic display ad in the ad group.
  create_ad($api_client, $customer_id, $ad_group_resource_name);

  # Target a specific user list for remarketing.
  attach_user_list($api_client, $customer_id, $ad_group_resource_name,
    $user_list_id);

  return 1;
}

# Creates a campaign linked to a Merchant Center product feed.
sub create_campaign {
  my ($api_client, $customer_id, $merchant_center_id, $campaign_budget_id) = @_;

  # Create a campaign.
  my $campaign = Google::Ads::GoogleAds::V2::Resources::Campaign->new({
      name => "Shopping campaign #" . uniqid(),
      # Dynamic remarketing campaigns are only available on the Google Display Network.
      advertisingChannelType => DISPLAY,
      status => Google::Ads::GoogleAds::V2::Enums::CampaignStatusEnum::PAUSED,
      campaignBudget =>
        Google::Ads::GoogleAds::V2::Utils::ResourceNames::campaign_budget(
        $customer_id, $campaign_budget_id
        ),
      manualCpc => Google::Ads::GoogleAds::V2::Common::ManualCpc->new(),
      # The settings for the shopping campaign.
      # This connects the campaign to the merchant center account.
      shoppingSetting =>
        Google::Ads::GoogleAds::V2::Resources::ShoppingSetting->new({
          campaignPriority => 0,
          merchantId       => $merchant_center_id,
          # Display Network campaigns do not support partition by country. The only
          # supported value is "ZZ". This signals that products from all countries are
          # available in the campaign. The actual products which serve are based on
          # the products tagged in the user list entry.
          salesCountry => "ZZ",
          enableLocal  => "true"
        })});

  # Create a campaign operation.
  my $campaign_operation =
    Google::Ads::GoogleAds::V2::Services::CampaignService::CampaignOperation->
    new({create => $campaign});

  # Add the campaign.
  my $campaign_response = $api_client->CampaignService()->mutate({
      customerId => $customer_id,
      operations => [$campaign_operation]});

  my $campaign_resource_name = $campaign_response->{results}[0]{resourceName};

  printf "Created campaign with resource name %s.\n", $campaign_resource_name;

  return $campaign_resource_name;
}

# Creates an ad group for the remarketing campaign.
sub create_ad_group {
  my ($api_client, $customer_id, $campaign_resource_name) = @_;

  # Create an ad group.
  my $ad_group = Google::Ads::GoogleAds::V2::Resources::AdGroup->new({
    name     => "Dynamic remarketing ad group",
    campaign => $campaign_resource_name,
    status   => Google::Ads::GoogleAds::V2::Enums::AdGroupStatusEnum::ENABLED
  });

  # Create an ad group operation.
  my $ad_group_operation =
    Google::Ads::GoogleAds::V2::Services::AdGroupService::AdGroupOperation->
    new({create => $ad_group});

  # Add the ad group.
  my $ad_group_response = $api_client->AdGroupService()->mutate({
      customerId => $customer_id,
      operations => [$ad_group_operation]});

  my $ad_group_resource_name = $ad_group_response->{results}[0]{resourceName};

  printf "Created ad group with resource name %s.\n", $ad_group_resource_name;

  return $ad_group_resource_name;
}

# Creates the responsive display ad.
sub create_ad {
  my ($api_client, $customer_id, $ad_group_resource_name) = @_;

  my $marketing_image_url  = "https://goo.gl/3b9Wfh";
  my $marketing_image_name = "Marketing Image";
  my $marketing_image_resource_name =
    upload_asset($api_client, $customer_id, $marketing_image_url,
    $marketing_image_name);

  my $logo_image_url  = "https://goo.gl/mtt54n";
  my $logo_image_name = "Logo Image";
  my $logo_image_resource_name =
    upload_asset($api_client, $customer_id, $logo_image_url, $logo_image_name);

  # Create a responsive display ad info object.
  my $responsive_display_ad_info =
    Google::Ads::GoogleAds::V2::Common::ResponsiveDisplayAdInfo->new({
      marketingImages => [
        Google::Ads::GoogleAds::V2::Common::AdImageAsset->new({
            asset => $marketing_image_resource_name
          })
      ],
      squareMarketingImages => [
        Google::Ads::GoogleAds::V2::Common::AdImageAsset->new({
            asset => $logo_image_resource_name
          })
      ],
      headlines => [
        Google::Ads::GoogleAds::V2::Common::AdTextAsset->new({
            text => "Travel"
          })
      ],
      longHeadline => Google::Ads::GoogleAds::V2::Common::AdTextAsset->new({
          text => "Travel the World"
        }
      ),
      descriptions => [
        Google::Ads::GoogleAds::V2::Common::AdTextAsset->new({
            text => "Take to the air!"
          })
      ],
      businessName => "Interplanetary Cruises",
      # Optional: Call to action text.
      # Valid texts: https://support.google.com/adwords/answer/7005917
      callToActionText => "Apply Now",
      # Optional: Create a logo image and set it to the ad.
      # logoImages => [
      #   Google::Ads::GoogleAds::V2::Common::AdImageAsset->new({
      #       asset => $logo_image_resource_name
      #     })
      # ],
      # Optional: Create a square logo image and set it to the ad.
      squareLogoImages => [
        Google::Ads::GoogleAds::V2::Common::AdImageAsset->new({
            asset => $logo_image_resource_name
          })
      ],
      # Whitelisted accounts only: Set color settings using hexadecimal values.
      # Set allowFlexibleColor to false if you want your ads to render by always
      # using your colors strictly.
      #
      # mainColor => "#0000ff"
      # accentColor => "#ffff00"
      # allowFlexibleColor => "false"
      #
      # Whitelisted accounts only: Set the format setting that the ad will be
      # served in.
      #
      # formatSetting => DisplayAdFormatSettingEnum::NON_NATIVE
      #
    });

  # Create an ad group ad.
  my $ad_group_ad = Google::Ads::GoogleAds::V2::Resources::AdGroupAd->new({
      adGroup => $ad_group_resource_name,
      ad      => Google::Ads::GoogleAds::V2::Resources::Ad->new({
          responsiveDisplayAd => $responsive_display_ad_info,
          finalUrls           => "http://www.example.com/"
        })});

  # Create an ad group ad operation.
  my $ad_group_ad_operation =
    Google::Ads::GoogleAds::V2::Services::AdGroupAdService::AdGroupAdOperation
    ->new({create => $ad_group_ad});

  # Add the ad group ad.
  my $ad_group_ad_response = $api_client->AdGroupAdService()->mutate({
      customerId => $customer_id,
      operations => [$ad_group_ad_operation]});

  printf "Created ad group ad with resource name %s.\n",
    $ad_group_ad_response->{results}[0]{resourceName};
}

# Adds an image to the Google Ads account.
sub upload_asset {
  my ($api_client, $customer_id, $image_url, $image_name) = @_;

  my $image_data = get_base64_data_from_url($image_url);

  # Create an image asset;
  my $asset = Google::Ads::GoogleAds::V2::Resources::Asset->new({
      name       => $image_name,
      type       => IMAGE,
      imageAsset => Google::Ads::GoogleAds::V2::Common::ImageAsset->new({
          data => $image_data
        })});

  # Create an asset operation.
  my $asset_operation =
    Google::Ads::GoogleAds::V2::Services::AssetService::AssetOperation->new({
      create => $asset
    });

  # Add the asset;
  my $asset_response = $api_client->AssetService()->mutate({
      customerId => $customer_id,
      operations => [$asset_operation]});

  my $image_resource_name = $asset_response->{results}[0]{resourceName};

  printf "Created image asset with resource name %s.\n", $image_resource_name;

  return $image_resource_name;
}

# Targets a user list.
sub attach_user_list {
  my ($api_client, $customer_id, $ad_group_resource_name, $user_list_id) = @_;

  # Create an ad group criterion that targets the user list.
  my $ad_group_criterion =
    Google::Ads::GoogleAds::V2::Resources::AdGroupCriterion->new({
      adGroup  => $ad_group_resource_name,
      userList => Google::Ads::GoogleAds::V2::Common::UserListInfo->new({
          userList =>
            Google::Ads::GoogleAds::V2::Utils::ResourceNames::user_list(
            $customer_id, $user_list_id
            )})});

  # Create an ad group criterion operation.
  my $ad_group_criterion_operation =
    Google::Ads::GoogleAds::V2::Services::AdGroupCriterionService::AdGroupCriterionOperation
    ->new({create => $ad_group_criterion});

  # Add the ad group criterion.
  my $ad_group_criterion_response =
    $api_client->AdGroupCriterionService()->mutate({
      customerId => $customer_id,
      operations => [$ad_group_criterion_operation]});

  printf "Created ad group criterion with resource name %s.\n",
    $ad_group_criterion_response->{results}[0]{resourceName};
}

# Don't run the example if the file is being included.
if (abs_path($0) ne abs_path(__FILE__)) {
  return 1;
}

# Get Google Ads Client, credentials will be read from ~/googleads.properties.
my $api_client = Google::Ads::GoogleAds::Client->new({version => "V2"});

# By default examples are set to die on any server returned fault.
$api_client->set_die_on_faults(1);

# Parameters passed on the command line will override any parameters set in code.
GetOptions(
  "customer_id=s"        => \$customer_id,
  "merchant_center_id=i" => \$merchant_center_id,
  "campaign_budget_id=i" => \$campaign_budget_id,
  "user_list_id=i"       => \$user_list_id
);

# Print the help message if the parameters are not initialized in the code nor
# in the command line.
pod2usage(2)
  if not check_params($customer_id, $merchant_center_id, $campaign_budget_id,
  $user_list_id);

# Call the example.
add_merchant_center_dynamic_remarketing_campaign($api_client,
  $customer_id =~ s/-//gr,
  $merchant_center_id, $campaign_budget_id, $user_list_id);

=pod

=head1 NAME

add_merchant_center_dynamic_remarketing_campaign

=head1 DESCRIPTION

This example creates a shopping campaign associated with an existing merchant center
account, along with a related ad group and dynamic display ad, and targets a user
list for remarketing purposes.

=head1 SYNOPSIS

add_merchant_center_dynamic_remarketing_campaign.pl [options]

    -help                       Show the help message.
    -customer_id                The Google Ads customer ID.
    -merchant_center_id         The Merchant Center ID.
    -campaign_budget_id         The campaign budget ID.
    -user_list_id               The user list ID.

=cut
