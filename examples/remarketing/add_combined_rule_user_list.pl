#!/usr/bin/perl -w
#
# Copyright 2020, Google LLC
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
# Creates a rule-based user list defined by a combination of rules for users who
# have visited two different pages of a website.

use strict;
use warnings;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../../lib";
use Google::Ads::GoogleAds::Client;
use Google::Ads::GoogleAds::Utils::GoogleAdsHelper;
use Google::Ads::GoogleAds::V4::Resources::UserList;
use Google::Ads::GoogleAds::V4::Common::UserListRuleItemInfo;
use Google::Ads::GoogleAds::V4::Common::UserListStringRuleItemInfo;
use Google::Ads::GoogleAds::V4::Common::UserListRuleInfo;
use Google::Ads::GoogleAds::V4::Common::UserListRuleItemGroupInfo;
use Google::Ads::GoogleAds::V4::Common::CombinedRuleUserListInfo;
use Google::Ads::GoogleAds::V4::Common::RuleBasedUserListInfo;
use Google::Ads::GoogleAds::V4::Enums::UserListStringRuleItemOperatorEnum
  qw(EQUALS);
use Google::Ads::GoogleAds::V4::Enums::UserListCombinedRuleOperatorEnum qw(AND);
use Google::Ads::GoogleAds::V4::Enums::UserListPrepopulationStatusEnum
  qw(REQUESTED);
use Google::Ads::GoogleAds::V4::Enums::UserListMembershipStatusEnum qw(OPEN);
use Google::Ads::GoogleAds::V4::Services::UserListService::UserListOperation;

use Getopt::Long qw(:config auto_help);
use Pod::Usage;
use Cwd qw(abs_path);
use Data::Uniqid qw(uniqid);

use constant URL_STRING => "url__";

# The following parameter(s) should be provided to run the example. You can
# either specify these by changing the INSERT_XXX_ID_HERE values below, or on
# the command line.
#
# Parameters passed on the command line will override any parameters set in
# code.
#
# Running the example with -h will print the command line usage.
my $customer_id = "INSERT_CUSTOMER_ID_HERE";

sub add_combined_rule_user_list {
  my ($api_client, $customer_id) = @_;

  # Create a rule targeting any user that visited a URL that equals
  # 'http://example.com/example1'.
  my $user_visited_site1_rule =
    Google::Ads::GoogleAds::V4::Common::UserListRuleItemInfo->new({
      # Use a built-in parameter to create a domain URL rule.
      name => URL_STRING,
      stringRuleItem =>
        Google::Ads::GoogleAds::V4::Common::UserListStringRuleItemInfo->new({
          operator => EQUALS,
          value    => "http://example.com/example1"
        })});

  # Create a UserListRuleInfo object containing the first rule.
  my $user_visited_site1_rule_info =
    Google::Ads::GoogleAds::V4::Common::UserListRuleInfo->new({
      ruleItemGroups =>
        Google::Ads::GoogleAds::V4::Common::UserListRuleItemGroupInfo->new({
          ruleItems => [$user_visited_site1_rule]})});

  # Create a rule targeting any user that visited a URL that equals
  # 'http://example.com/example2'.
  my $user_visited_site2_rule =
    Google::Ads::GoogleAds::V4::Common::UserListRuleItemInfo->new({
      # Use a built-in parameter to create a domain URL rule.
      name => URL_STRING,
      stringRuleItem =>
        Google::Ads::GoogleAds::V4::Common::UserListStringRuleItemInfo->new({
          operator => EQUALS,
          value    => "http://example.com/example2"
        })});

  # Create a UserListRuleInfo object containing the second rule.
  my $user_visited_site2_rule_info =
    Google::Ads::GoogleAds::V4::Common::UserListRuleInfo->new({
      ruleItemGroups =>
        Google::Ads::GoogleAds::V4::Common::UserListRuleItemGroupInfo->new({
          ruleItems => [$user_visited_site2_rule]})});

  # Create the user list where "Visitors of a page who did visit another page".
  # To create a user list where "Visitors of a page who did not visit another page",
  # change the UserListCombinedRuleOperator from AND to AND_NOT.
  my $combined_rule_user_list_info =
    Google::Ads::GoogleAds::V4::Common::CombinedRuleUserListInfo->new({
      leftOperand  => $user_visited_site1_rule_info,
      rightOperand => $user_visited_site2_rule_info,
      ruleOperator => AND
    });

  # Define a representation of a user list that is generated by a rule.
  my $rule_based_user_list_info =
    Google::Ads::GoogleAds::V4::Common::RuleBasedUserListInfo->new({
      # Optional: To include past users in the user list, set the prepopulationStatus
      # to REQUESTED.
      prepopulationStatus  => REQUESTED,
      combinedRuleUserList => $combined_rule_user_list_info
    });

  # Create a user list.
  my $user_list = Google::Ads::GoogleAds::V4::Resources::UserList->new({
    name => "All visitors to http://example.com/example1 AND " .
      "http://example.com/example2 #" . uniqid(),
    description => "Visitors of both http://example.com/example1 AND " .
      "http://example.com/example2",
    membershipStatus   => OPEN,
    membershipLifeSpan => 365,
    ruleBasedUserList  => $rule_based_user_list_info
  });

  # Create the operation.
  my $user_list_operation =
    Google::Ads::GoogleAds::V4::Services::UserListService::UserListOperation->
    new({
      create => $user_list
    });

  # Issue a mutate request to add the user list and print some information.
  my $user_list_response = $api_client->UserListService()->mutate({
      customerId => $customer_id,
      operations => [$user_list_operation]});
  printf "Created user list with resource name '%s'.\n",
    $user_list_response->{results}[0]{resourceName};

  return 1;
}

# Don't run the example if the file is being included.
if (abs_path($0) ne abs_path(__FILE__)) {
  return 1;
}

# Get Google Ads Client, credentials will be read from ~/googleads.properties.
my $api_client = Google::Ads::GoogleAds::Client->new();

# By default examples are set to die on any server returned fault.
$api_client->set_die_on_faults(1);

# Parameters passed on the command line will override any parameters set in code.
GetOptions("customer_id=s" => \$customer_id);

# Print the help message if the parameters are not initialized in the code nor
# in the command line.
pod2usage(2) if not check_params($customer_id);

# Call the example.
add_combined_rule_user_list($api_client, $customer_id =~ s/-//gr);

=pod

=head1 NAME

add_combined_rule_user_list

=head1 DESCRIPTION

Creates a rule-based user list defined by a combination of rules for users who
have visited two different pages of a website.

=head1 SYNOPSIS

add_combined_rule_user_list.pl [options]

    -help                       Show the help message.
    -customer_id                The Google Ads customer ID.

=cut