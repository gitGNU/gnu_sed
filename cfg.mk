# Customize maint.mk                           -*- makefile -*-
# Copyright (C) 2009-2017 Free Software Foundation, Inc.

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Cause the tool(s) built by this package to be used also when running
# commands via e.g., "make syntax-check".  Doing this a little sooner
# would have avoided a grep infloop bug.
export PATH := $(srcdir)/sed:${PATH}

# Used in maint.mk's web-manual rule
manual_title = GNU Sed: a stream editor

# Use the direct link.  This is guaranteed to work immediately, while
# it can take a while for the faster mirror links to become usable.
url_dir_list = http://ftp.gnu.org/gnu/$(PACKAGE)

# Tests not to run as part of "make distcheck".
local-checks-to-skip =			\
  sc_GPL_version			\
  sc_bindtextdomain			\
  sc_error_message_uppercase		\
  sc_preprocessor_indentation		\
  sc_prohibit_atoi_atof			\
  sc_prohibit_magic_number_exit		\
  sc_prohibit_strcmp			\
  sc_texinfo_acronym			\
  sc_unmarked_diagnostics		\
  sc_useless_cpp_parens

# Tools used to bootstrap this package, used for "announcement".
bootstrap-tools = autoconf,automake,gnulib

# Override the default Cc: used in generating an announcement.
announcement_Cc_ = $(translation_project_), sed-devel@gnu.org

# Now that we have better tests, make this the default.
export VERBOSE = yes

# Comparing tarball sizes compressed using different xz presets, we see
# that -6e adds only 60 bytes to the size of the tarball, yet reduces
# (from -9) the decompression memory requirement from 64 MiB to 9 MiB.
# Don't be tempted by -5e, since -6 and -5 use the same dictionary size.
# $ for i in {4,5,6,7,8,9}{e,}; do
#   (n=$(xz -$i < sed-4.2.2.tar |wc -c);echo $n $i) & done |sort -nr
# 900032 4
# 854932 5
# 844572 4e
# 843780 9
# 843780 8
# 843780 7
# 843780 6
# 837892 5e
# 836832 9e
# 836832 8e
# 836832 7e
# 836832 6e
export XZ_OPT = -6e

old_NEWS_hash = f245b991bf987599a73422379271f54d

# Many m4 macros names once began with 'jm_'.
# Make sure that none are inadvertently reintroduced.
sc_prohibit_jm_in_m4:
	@grep -nE 'jm_[A-Z]'						\
		$$($(VC_LIST) m4 |grep '\.m4$$'; echo /dev/null) &&	\
	    { echo '$(ME): do not use jm_ in m4 macro names'		\
	      1>&2; exit 1; } || :

sc_prohibit_echo_minus_en:
	@prohibit='\<echo -[en]'					\
	halt='do not use echo ''-e or echo ''-n; use printf instead'	\
	  $(_sc_search_regexp)

# Look for lines longer than 80 characters, except omit:
# - program-generated long lines in diff headers,
# - the help2man script copied from upstream,
# - tests involving long checksum lines, and
# - the 'pr' test cases.
LINE_LEN_MAX = 80
FILTER_LONG_LINES =						\
  /^[^:]*\.diff:[^:]*:@@ / d;					\
  \|^[^:]*man/help2man:| d;			\
  \|^[^:]*tests/misc/sha[0-9]*sum.*\.pl[-:]| d;			\
  \|^[^:]*tests/pr/|{ \|^[^:]*tests/pr/pr-tests:| !d; };
sc_long_lines:
	@files=$$($(VC_LIST_EXCEPT))					\
	halt='line(s) with more than $(LINE_LEN_MAX) characters; reindent'; \
	for file in $$files; do						\
	  expand $$file | grep -nE '^.{$(LINE_LEN_MAX)}.' |		\
	  sed -e "s|^|$$file:|" -e '$(FILTER_LONG_LINES)';		\
	done | grep . && { msg="$$halt" $(_sc_say_and_exit) } || :

# Indent only with spaces.
sc_prohibit_tab_based_indentation:
	@prohibit='^ *	'						\
	halt='TAB in indentation; use only spaces'			\
	  $(_sc_search_regexp)

# Don't use "indent-tabs-mode: nil" anymore.  No longer needed.
sc_prohibit_emacs__indent_tabs_mode__setting:
	@prohibit='^( *[*#] *)?indent-tabs-mode:'			\
	halt='use of emacs indent-tabs-mode: setting'			\
	  $(_sc_search_regexp)

# Enforce recommended preprocessor indentation style.
sc_preprocessor_indentation:
	@if cppi --version >/dev/null 2>&1; then			\
	  $(VC_LIST_EXCEPT) | grep '\.[ch]$$' | xargs cppi -a -c	\
	    || { echo '$(ME): incorrect preprocessor indentation' 1>&2;	\
		exit 1; };						\
	else								\
	  echo '$(ME): skipping test $@: cppi not installed' 1>&2;	\
	fi

# THANKS.in is a list of name/email pairs for people who are mentioned in
# commit logs (and generated ChangeLog), but who are not also listed as an
# author of a commit.  Name/email pairs of commit authors are automatically
# extracted from the repository.  As a very minor factorization, when
# someone who was initially listed only in THANKS.in later authors a commit,
# this rule detects that their pair may now be removed from THANKS.in.
sc_THANKS_in_duplicates:
	@{ git log --pretty=format:%aN | sort -u;			\
	    cut -b-36 THANKS.in | sed '/^$$/d;s/  *$$//'; }		\
	  | sort | uniq -d | grep .					\
	    && { echo '$(ME): remove the above names from THANKS.in'	\
		  1>&2; exit 1; } || :

# Ensure the contributor list stays sorted.  However, if the system's
# en_US.UTF-8 locale data is erroneous, give a diagnostic and skip
# this test.  This affects OS X up to at least 10.11.6.
sc_THANKS_in_sorted:
	@printf '%s\n' ja j.b| LC_ALL=en_US.UTF-8 sort -c 2> /dev/null	\
	  && {								\
	    sed '/^$$/,/^$$/!d;/^$$/d' $(srcdir)/THANKS.in > $@.1 &&	\
	    LC_ALL=en_US.UTF-8 sort -f -k1,1 $@.1 > $@.2 &&		\
	    diff -u $@.1 $@.2; diff=$$?;				\
	    rm -f $@.1 $@.2;						\
	    test "$$diff" = 0						\
	      || { echo '$(ME): THANKS.in is unsorted' 1>&2; exit 1; };	\
	    }								\
	  || { echo '$(ME): this system has erroneous locale data;'	\
		    'skipping $@' 1>&2; }

update-copyright-env = \
  UPDATE_COPYRIGHT_USE_INTERVALS=2 \
  UPDATE_COPYRIGHT_MAX_LINE_LENGTH=79

config_h_header ?= (<config\.h>|"sed\.h")

exclude_file_name_regexp--sc_long_lines = ^tests/.*$$
exclude_file_name_regexp--sc_prohibit_doubled_word = \
  ^testsuite/(mac-mf|uniq)\.(good|inp)$$

exclude_file_name_regexp--sc_program_name = ^testsuite/.*\.c$$

exclude_file_name_regexp--sc_space_tab = ^testsuite/.*$$
exclude_file_name_regexp--sc_prohibit_always_true_header_tests = \
  ^configure\.ac$$

tbi_1 = (^testsuite/.*|^gl/lib/reg.*\.c\.diff|\.mk|/help2man)$$
tbi_2 = (GNU)?[Mm]akefile(\.am)?$$
exclude_file_name_regexp--sc_prohibit_tab_based_indentation = \
  $(tbi_1)|$(tbi_2)

exclude_file_name_regexp--sc_prohibit_empty_lines_at_EOF = \
  ^testsuite/(bkslashes.good|(noeolw?|empty|zero-anchor)\.(2?good|inp))$$

# Exempt test-related files from our 80-column limitation, for now.
exclude_file_name_regexp--sc_long_lines = ^testsuite/


# static analysis
STAN_CFLAGS ?= "-g -O0"

.PHONY: static-analysis-init
static-analysis-init:
	type scan-build 1>/dev/null 2>&1 || \
	    { echo "scan-build program not found" >&2; exit 1; }
	$(MAKE) clean

.PHONY: static-analysis-config
static-analysis-config:
	test -x ./configure || \
	    { echo "./configure script not found" >&2; exit 1; }
	scan-build ./configure CFLAGS=$(STAN_CFLAGS)

.PHONY: static-analysis-make
static-analysis-make:
	scan-build $(MAKE)

.PHONY: static-analysis
static-analysis: static-analysis-init static-analysis-config \
                 static-analysis-make
