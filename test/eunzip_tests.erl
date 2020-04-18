%% @author: Maxim Pushkar
%% @date: 17.04.2020

-module(eunzip_tests).

%% Include files
-include_lib("eunit/include/eunit.hrl").
-include("eunzip.hrl").

%% API
-export([]).

%% Macros
-define(eunzip, eunzip).

%% API
open_close_test() ->
    OpenResult = eunzip:open(otp_23_readme_zip()),
    ?assertMatch({ok, _}, OpenResult, "Failed to open a ZIP archive"),
    {ok, UnzipState} = OpenResult,
    ?assertEqual(ok, eunzip:close(UnzipState), "Failed to close file").

entries_test() ->
    OpenResult = eunzip:open(otp_23_readme_zip()),
    ?assertMatch({ok, _}, OpenResult, "Failed to open a ZIP archive"),
    {ok, UnzipState} = OpenResult,
    CdFileName = otp_23_readme_filename(),
    ?assertMatch({ok, [#cd_entry{file_name = CdFileName}]}, eunzip:entries(UnzipState), "Failed to get entries"),
    ?assertEqual(ok, eunzip:close(UnzipState), "Failed to close file").

entries2_test() ->
    OpenResult = eunzip:open(specs_zip()),
    ?assertMatch({ok, _}, OpenResult, "Failed to open a ZIP archive"),
    {ok, UnzipState} = OpenResult,
    ?assertMatch({ok, [_, _, _]}, eunzip:entries(UnzipState), "Failed to get entries"),
    ?assertEqual(ok, eunzip:close(UnzipState), "Failed to close file").

entry_test() ->
    OpenResult = eunzip:open(otp_23_readme_zip()),
    ?assertMatch({ok, _}, OpenResult, "Failed to open a ZIP archive"),
    {ok, UnzipState} = OpenResult,
    CdFileName = otp_23_readme_filename(),
    ?assertMatch({ok, #cd_entry{file_name = CdFileName}}, eunzip:entry(UnzipState, CdFileName), "Failed to get file entry"),
    ?assertEqual(ok, eunzip:close(UnzipState), "Failed to close file").

is_file_test() ->
    OpenResult = eunzip:open(otp_23_readme_zip()),
    ?assertMatch({ok, _}, OpenResult, "Failed to open a ZIP archive"),
    {ok, UnzipState} = OpenResult,
    ?assertEqual({ok, true}, eunzip:is_file(UnzipState, otp_23_readme_filename()), "Failed to check if entry is a regular file"),
    ?assertEqual(ok, eunzip:close(UnzipState), "Failed to close file").

is_dir_test() ->
    OpenResult = eunzip:open(specs_zip()),
    ?assertMatch({ok, _}, OpenResult, "Failed to open a ZIP archive"),
    {ok, UnzipState} = OpenResult,
    ?assertEqual({ok, true}, eunzip:is_dir(UnzipState, specs_dir()), "Failed to check if entry is a directory"),
    ?assertEqual(ok, eunzip:close(UnzipState), "Failed to close file").

verify_test() ->
    OpenResult = eunzip:open(otp_23_readme_zip()),
    ?assertMatch({ok, _}, OpenResult, "Failed to open a ZIP archive"),
    {ok, UnzipState} = OpenResult,
    ?assertEqual(ok, eunzip:verify(UnzipState, otp_23_readme_filename()), "CRC32 mismatch"),
    ?assertEqual(ok, eunzip:close(UnzipState), "Failed to close file").

deflate_test() ->
    OpenResult = eunzip:open(otp_23_readme_zip()),
    ?assertMatch({ok, _}, OpenResult, "Failed to open a ZIP archive"),
    {ok, UnzipState} = OpenResult,
    CdFileName = otp_23_readme_filename(),
    ?assertEqual(ok, eunzip:decompress(UnzipState, CdFileName, CdFileName), "Failed to decompress file"),
    file:delete(otp_23_readme_filename()),
    ?assertEqual(ok, eunzip:close(UnzipState), "Failed to close file").

stream_test() ->
    OpenResult = eunzip:open(otp_23_readme_zip()),
    ?assertMatch({ok, _}, OpenResult, "Failed to open a ZIP archive"),
    {ok, UnzipState} = OpenResult,
    CdFileName = otp_23_readme_filename(),
    StreamInitResult = eunzip:stream_init(UnzipState, CdFileName),
    ?assertMatch({ok, _}, StreamInitResult, "Failed to start file stream"),
    {ok, StreamState} = StreamInitResult,
    ExpectedMd5 = <<224, 197, 17, 243, 183, 239, 151, 148, 52, 62, 2, 208, 63, 223, 55, 59>>,
    Md5State = crypto:hash_init(md5),
    StreamResult = stream_iterator(StreamState, Md5State),
    ?assertMatch({ok, _}, StreamResult, "Failed to stream file contents"),
    ?assertMatch({ok, ExpectedMd5}, StreamResult, "Imvalid MD5 checksum"),
    ?assertEqual(ok, eunzip:close(UnzipState), "Failed to close file").

%% Internal functions
test_path(FileName) ->
    Dir = code:lib_dir(?eunzip),
    Path = filename:join([Dir, "test", "files", FileName]),
    iolist_to_binary(Path).

otp_23_readme_zip() ->
    test_path("otp_23_readme.zip").

otp_23_readme_filename() ->
    <<"otp_src_23.0-rc2.readme.txt">>.

specs_zip() ->
    test_path("specs.zip").

specs_dir() ->
    <<"specs/">>.

stream_iterator(StreamState, Md5State) ->
    case eunzip:stream_read_chunk(?file_chunk_size, StreamState) of
        {ok, Data, StreamState1} ->
            Md5State1 = crypto:hash_update(Md5State, Data),
            eunzip:stream_end(StreamState1),
            {ok, crypto:hash_final(Md5State1)};
        {more, Data, StreamState1} ->
            stream_iterator(StreamState1, crypto:hash_update(Md5State, Data));
        {error, Reason, StreamState} ->
            eunzip:stream_end(StreamState),
            {error, Reason}
    end.
