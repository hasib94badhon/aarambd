import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'language_provider.dart';

class AppLocalizations {
  final String languageCode;
  const AppLocalizations(this.languageCode);

  bool get isBn => languageCode == 'bn';
  String _t(String en, String bn) => isBn ? bn : en;

  static AppLocalizations of(BuildContext context) =>
      Provider.of<LanguageProvider>(context, listen: false).l10n;

  // ── App brand ─────────────────────────────────────────────────────────────
  String get appName => _t('AaramBD', 'আড়ামবিডি');
  String get appTagline =>
      _t('Best Marketplace in Bangladesh', 'বাংলাদেশের সেরা মার্কেটপ্লেস');

  // ── Navigation ────────────────────────────────────────────────────────────
  String get navFeeds => _t('Live', 'লাইভ');
  String get navTop => _t('Top', 'টপ');
  String get navExperts => _t('Experts', 'বিশেষজ্ঞ');
  String get navProfile => _t('Profile', 'প্রোফাইল');
  String get navThought => _t('Thought', 'থট');
  String get navMart => _t('Mart', 'মার্ট');
  String get navPost => _t('Post', 'পোস্ট');
  String get navMartTitle => _t('Mart / Shop', 'মার্ট / দোকান');
  String get navUpdatePostTitle => _t('Update Post', 'আপডেট পোস্ট');
  String get loading => _t('Loading…', 'লোড হচ্ছে…');

  // ── Login ─────────────────────────────────────────────────────────────────
  String get loginWelcome => _t('Welcome 👋', 'স্বাগতম 👋');
  String get loginSubtitle =>
      _t('Sign in to your account', 'আপনার অ্যাকাউন্টে প্রবেশ করুন');
  String get loginMobileLabel => _t('Mobile Number', 'মোবাইল নম্বর');
  String get loginPasswordLabel => _t('Password', 'পাসওয়ার্ড');
  String get loginRememberMe => _t('Remember me', 'মনে রাখুন');
  String get loginForgotPassword =>
      _t('Forgot password?', 'পাসওয়ার্ড ভুলে গেছেন?');
  String get loginButton => _t('Sign In', 'লগইন করুন');
  String get loginOr => _t('or', 'অথবা');
  String get loginNoAccount =>
      _t("Don't have an account?", 'অ্যাকাউন্ট নেই?');
  String get loginSignUp => _t('Register →', 'নিবন্ধন করুন →');
  String get loginSuccess => _t('Login successful', 'লগইন সফল হয়েছে');
  String get loginFailed => _t('Login failed', 'লগইন ব্যর্থ হয়েছে');
  String get loginUnexpectedError => _t(
      'An unexpected error occurred. Please try again.',
      'একটি অপ্রত্যাশিত ত্রুটি হয়েছে। আবার চেষ্টা করুন।');
  String get loginErrorTitle =>
      _t('Something went wrong', 'কিছু একটা ভুল হয়েছে');
  String get loginOkButton => _t('OK', 'ঠিক আছে');
  String get loginEnterPhone =>
      _t('Please enter your phone number.', 'আপনার ফোন নম্বর দিন।');

  // ── Sign Up ───────────────────────────────────────────────────────────────
  String get signupTitle =>
      _t('Create New\nAccount', 'নতুন অ্যাকাউন্ট\nতৈরি করুন');
  String get signupTagline => _t(
      'Join today to connect with\nthe best service providers.',
      'সেরা সেবাদাতাদের সাথে\nযুক্ত হতে আজই যোগ দিন।');
  String get signupFormTitle => _t('Enter your details', 'আপনার তথ্য দিন');
  String get signupFormSubtitle =>
      _t('Register with correct information', 'সঠিক তথ্য দিয়ে নিবন্ধন করুন');
  String get signupNameLabel => _t('Your Name', 'আপনার নাম');
  String get signupNameHint => _t('Enter full name', 'পূর্ণ নাম লিখুন');
  String get signupPhoneLabel => _t('Mobile Number', 'মোবাইল নম্বর');
  String get signupPasswordLabel => _t('Password', 'পাসওয়ার্ড');
  String get signupPasswordHint =>
      _t('Use at least 6 characters', 'কমপক্ষে ৬টি অক্ষর ব্যবহার করুন');
  String get signupButton => _t('Create Account', 'অ্যাকাউন্ট তৈরি করুন');
  String get signupLoadingButton => _t('Registering...', 'নিবন্ধন হচ্ছে...');
  String get signupBadgeSafe => _t('Safe', 'নিরাপদ');
  String get signupBadgeEncrypted => _t('Encrypted', 'এনক্রিপ্টেড');
  String get signupBadgeTrusted => _t('Trusted', 'বিশ্বস্ত');
  String get signupSecretTitle =>
      _t('Enter Secret Number', 'গোপন নম্বর দিন');
  String get signupSecretSubtitle =>
      _t('Required for security', 'নিরাপত্তার জন্য প্রয়োজনীয়');
  String get signupSecretDescription => _t(
      'This number will be used for password recovery. Choose one you can remember.',
      'এই নম্বরটি পাসওয়ার্ড পুনরুদ্ধারে কাজে লাগবে। মনে রাখার মতো একটি নম্বর বেছে নিন।');
  String get signupCancel => _t('Cancel', 'বাতিল');
  String get signupConfirm => _t('Confirm', 'নিশ্চিত করুন');
  String get signupSuccess =>
      _t('Registration successful', 'নিবন্ধন সফল হয়েছে');
  String get signupFailed =>
      _t('Registration failed', 'নিবন্ধন ব্যর্থ হয়েছে');
  String get signupOr => _t('or', 'অথবা');
  String get signupHaveAccount =>
      _t('Already have an account?', 'ইতিমধ্যে অ্যাকাউন্ট আছে?');
  String get signupLoginLink => _t('Sign In →', 'লগইন করুন →');

  // ── OTP ───────────────────────────────────────────────────────────────────
  String get otpTitle => _t('Verification', 'যাচাইকরণ');
  String get otpHeader => _t('Verify Your Identity', 'আপনার পরিচয় যাচাই করুন');
  String get otpSubHeader => _t(
      'Enter your phone number and secret number to continue.',
      'আপনার ফোন নম্বর এবং গোপন নম্বর দিয়ে এগিয়ে যান।');
  String get otpPhoneLabel => _t('Phone Number', 'ফোন নম্বর');
  String get otpSecretLabel => _t('Secret Number', 'গোপন নম্বর');
  String get otpSecretHint =>
      _t('Enter your secret number', 'আপনার গোপন নম্বর দিন');
  String get otpVerifyButton => _t('Verify', 'যাচাই করুন');
  String get otpTip => _t(
      'Tip: Use the secret number you entered during registration.',
      'টিপস: নিবন্ধনের সময় যে গোপন নম্বরটি দিয়েছিলেন সেটি ব্যবহার করুন।');
  String get otpNeedHelp => _t('Need help?', 'সাহায্য দরকার?');
  String get otpContactSupport => _t(
      'Contact AaramBD support team',
      'আড়ামবিডি সাপোর্ট টিমের সাথে যোগাযোগ করুন');
  String get otpFieldsRequired => _t(
      'Phone number and secret number are required',
      'ফোন নম্বর এবং গোপন নম্বর আবশ্যক');
  String get otpVerificationFailed =>
      _t('Verification failed', 'যাচাইকরণ ব্যর্থ হয়েছে');
  String get otpSupportMessage => _t(
      'AaramBD support team will contact you shortly.',
      'আড়ামবিডি সাপোর্ট টিম শীঘ্রই আপনার সাথে যোগাযোগ করবে।');

  // ── Profile ───────────────────────────────────────────────────────────────
  String get profileCalls => _t('calls', 'কল');
  String get profileViews => _t('views', 'ভিউ');
  String get profileEdit => _t('Edit', 'এডিট');
  String get profilePost => _t('Post', 'পোস্ট');
  String get profileShare => _t('Share', 'শেয়ার');
  String get profileNoPosts => _t('No posts found', 'কোনো পোস্ট নেই');
  String get profileCallActive =>
      _t('Everyone can call you now', 'সবাই এখন আপনাকে কল করতে পারবেন');
  String get profileCallInactive =>
      _t('No one can call you now.', 'কেউ এখন আপনাকে কল করতে পারবেন না।');
  String get profileAllowMarket =>
      _t('Allow market to reach you', 'মার্কেটকে আপনার কাছে পৌঁছাতে দিন');
  String get profileActive => _t('ACTIVE', 'সক্রিয়');
  String get profileInactive => _t('INACTIVE', 'নিষ্ক্রিয়');
  String get profileTotalCollections =>
      _t('Total Collections', 'মোট সংগ্রহ');
  String get profileSeeDetails => _t('See details', 'বিস্তারিত দেখুন');
  String get profilePortalTitle => _t('Portal', 'পোর্টাল');
  String get profilePortalSubtitle => _t(
      'Write thoughts • Discuss • Explore ideas',
      'লিখুন • আলোচনা করুন • ধারণা অন্বেষণ করুন');
  String get profilePortalOpen => _t('Open', 'খুলুন');
  String get profileOptions => _t('Options', 'অপশন');
  String get profileConfirmDelete =>
      _t('Confirm Delete', 'মুছে ফেলার নিশ্চিতকরণ');
  String get profileDeleteMessage => _t(
      'Are you sure you want to delete this post?',
      'আপনি কি এই পোস্টটি মুছে ফেলতে চান?');
  String get profileCancel => _t('Cancel', 'বাতিল');
  String get profileDelete => _t('Delete', 'মুছুন');
  String get profileModify => _t('Modify', 'পরিবর্তন করুন');
  String get profileDeleteSuccess =>
      _t('Post deleted successfully!', 'পোস্ট সফলভাবে মুছে ফেলা হয়েছে!');
  String get profileDeleteFailed => _t(
      "Couldn't delete the post. Try again!",
      'পোস্ট মুছে ফেলা যায়নি। আবার চেষ্টা করুন!');
  String get profileUpdateSuccess =>
      _t('Post updated successfully!', 'পোস্ট সফলভাবে আপডেট হয়েছে!');
  String get profileLinkSaved =>
      _t('Link saved successfully', 'লিংক সফলভাবে সেভ হয়েছে');
  String get profileErrorSharing =>
      _t('Error sharing: ', 'শেয়ার করতে সমস্যা: ');
  String get profileNoDescription => _t('No description', 'কোনো বিবরণ নেই');
  String get profileViewsStat => _t('Views', 'ভিউ');
  String get profileCommentsStat => _t('Comments', 'মন্তব্য');
  String get profilePostsCount => _t('Posts', 'পোস্ট');

  // ── Sorting ───────────────────────────────────────────────────────────────
  String get sortPosts => _t('Sort Posts', 'পোস্ট সাজান');
  String get sortRecent => _t('Recent', 'সাম্প্রতিক');
  String get sortViewed => _t('Viewed', 'সর্বাধিক দেখা');
  String get sortCommented => _t('Commented', 'সর্বাধিক মন্তব্য');

  // ── Language toggle ───────────────────────────────────────────────────────
  String get languageLabel => _t('Language', 'ভাষা');
  static const String langEnglish = 'English';
  static const String langBangla = 'বাংলা';

  // ── Thought section ───────────────────────────────────────────────────────
  String get thoughtTitle => _t('My Thoughts', 'আমার চিন্তা');
  String get thoughtChooseCategory => _t('Choose Category', 'বিভাগ বেছে নিন');
  String get thoughtNoCategorySelected =>
      _t('No category selected', 'কোনো বিভাগ নির্বাচিত হয়নি');
  String get thoughtCategorySelected => _t('✓ Selected', '✓ নির্বাচিত');
  String get thoughtLoadingCategories =>
      _t('Loading categories…', 'বিভাগ লোড হচ্ছে…');
  String get thoughtWriteHeader =>
      _t('Write your thought', 'আপনার চিন্তা লিখুন');
  String get thoughtInputHint => _t(
      'Write your thought or use suggestions below…',
      'আপনার চিন্তা লিখুন বা নিচের সাজেশন ব্যবহার করুন…');
  String get thoughtAddPhoto => _t('Add photo', 'ছবি যোগ করুন');
  String get thoughtWritingAssistant =>
      _t('Writing assistant', 'লেখার সাহায্যকারী');
  String get thoughtRemoveWord => _t('← Remove word', '← শব্দ মুছুন');
  String get thoughtClearAll => _t('Clear all', 'সব মুছুন');
  String get thoughtImprove => _t('✨ Improve', '✨ উন্নত করুন');
  String get thoughtPosting => _t('Posting…', 'পোস্ট করা হচ্ছে…');
  String get thoughtPost => _t('Post', 'পোস্ট করুন');
  String get thoughtMyPostsLabel =>
      _t('My Posts', 'আমার পোস্টগুলো');
  String get thoughtPostsLoading =>
      _t('Loading posts…', 'পোস্ট লোড হচ্ছে…');
  String get thoughtNoPosts => _t('No posts yet', 'এখনো কোনো পোস্ট নেই');
  String get thoughtFirstPost =>
      _t('Share your first thought!', 'আপনার প্রথম চিন্তাটি শেয়ার করুন!');
  String get thoughtSeeMore => _t('See more ▼', 'আরো দেখুন ▼');
  String get thoughtSeeLess => _t('See less ▲', 'কম দেখুন ▲');
  String get thoughtSeeDetails => _t('See details', 'বিস্তারিত দেখুন');
  String get thoughtViewsCount => _t('views', 'বার দেখা হয়েছে');
  String get thoughtDeleteTitle =>
      _t('Delete post?', 'পোস্ট মুছে ফেলবেন?');
  String get thoughtDeleteContent => _t(
      'This thought will be permanently removed.',
      'এই চিন্তাটি স্থায়ীভাবে সরিয়ে দেওয়া হবে।');
  String get thoughtDeleteCancel => _t('Cancel', 'বাতিল');
  String get thoughtDeleteConfirm => _t('Delete', 'মুছুন');
  String get thoughtRequiredFields => _t(
      'Write text and choose a category.',
      'টেক্সট লিখুন এবং একটি বিভাগ বেছে নিন।');
  String get thoughtDeleting => _t('Deleting…', 'মুছে ফেলা হচ্ছে…');
  String get thoughtImproveSuccess =>
      _t('Sentence improved ✨', 'বাক্য উন্নত করা হয়েছে ✨');

  List<String> get thoughtStepLabels => isBn
      ? ['কে? (বিষয়)', 'কী করবেন?', 'কী লাগবে?', 'কখন / কোথায়?']
      : ['Who? (Subject)', 'What to do?', 'What is needed?', 'When / Where?'];
}
