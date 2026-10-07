open Lwt.Syntax

module Conf = struct
  let entries = 32
  let stable_hash = 256
  let contents_length_header = Some `Varint
  let inode_child_order = `Seeded_hash
  let forbid_empty_dir_persistence = true
end

module Schema = struct
  open Irmin
  module Metadata = Metadata.None
  module Contents = Contents.String_v2
  module Path = Path.String_list
  module Branch = Branch.String
  module Hash = Hash.SHA1
  module Node = Node.Generic_key.Make_v2 (Hash) (Path) (Metadata)
  module Commit = Commit.Generic_key.Make_v2 (Hash)
  module Info = Info.Default
end

module Store = struct
  module Maker = Irmin_pack_unix.Maker (Conf)
  include Maker.Make (Schema)
end

module Io = Irmin_pack_unix.Io.Unix
module Volume_control = Irmin_pack_unix.Control_file.Volume (Io)
module Int63 = Optint.Int63

let copy_file src dst =
  let data = In_channel.with_open_bin src In_channel.input_all in
  Out_channel.with_open_bin dst (fun oc -> output_string oc data)

let config ~fresh ~root ~lower_root =
  Irmin_pack.config ~fresh
    ~indexing_strategy:Irmin_pack.Indexing_strategy.minimal
    ~lower_root:(Some lower_root) root

let generation repo =
  let open Store.Internal in
  let ({ status; _ } : Irmin_pack_unix.Control_file.Payload.Upper.Latest.t) =
    file_manager repo |> File_manager.control |> File_manager.Control.payload
  in
  match status with
  | Gced { generation; _ } -> generation
  | _ -> failwith "expected Gced status"

let commit_is_in_lower ~lower_root commit =
  match Irmin_pack_unix.Pack_key.inspect (Store.Commit.key commit) with
  | Direct { volume_identifier = Some _; _ } -> true
  | Direct { offset; _ } -> (
      let volume_control =
        Irmin_pack.Layout.V5.Volume.control
          ~root:(Irmin_pack.Layout.V5.Volume.directory ~idx:0 ~root:lower_root)
      in
      match Volume_control.read_payload ~path:volume_control with
      | Ok payload ->
          let open Int63.Syntax in
          payload.start_offset <= offset && offset < payload.end_offset
      | Error _ -> false)
  | Indexed _ -> false

let read_commit repo hash =
  Lwt.catch
    (fun () ->
      let+ c = Store.Commit.of_hash repo hash in
      match c with
      | None -> Error "not found"
      | Some c -> Ok c)
    (fun exn -> Lwt.return (Error (Printexc.to_string exn)))

let pp_read label = function
  | Ok _ -> Printf.printf "%s PASS\n%!" label
  | Error e -> Printf.printf "%s FAIL %s\n%!" label e

let run () =
  let root = "_build/repro-moment-b-public" in
  let lower_root = root ^ ".lower" in
  ignore (Sys.command ("rm -rf " ^ Filename.quote root));
  ignore (Sys.command ("rm -rf " ^ Filename.quote lower_root));

  let* repo = Store.Repo.v (config ~fresh:true ~root ~lower_root) in
  let* main = Store.main repo in
  let info () = Store.Info.v ~author:"moment-b-repro" Int64.zero in

  let volume_root =
    Irmin_pack.Layout.V5.Volume.directory ~idx:0 ~root:lower_root
  in
  let volume_control =
    Irmin_pack.Layout.V5.Volume.control ~root:volume_root
  in
  let old_backup = volume_control ^ ".pre-gc" in

  (* Step 1: Commit c1, c2 and run initial GC to populate volume.0
     and create volume.control on disk. *)
  let* () = Store.set_exn ~info main [ "k" ] "v1" in
  let* _ = Store.Head.get main in
  let* () = Store.set_exn ~info main [ "k" ] "v2" in
  let* c2 = Store.Head.get main in

  let* _ = Store.Gc.start_exn repo (Store.Commit.key c2) in
  let* _ = Store.Gc.finalise_exn ~wait:true repo in

  (* volume.control now exists. Backup this pre-GC payload for the second GC *)
  copy_file volume_control old_backup;

  (* Step 2: Commit c3, c4 and run second GC to extend the volume range *)
  let* () = Store.set_exn ~info main [ "k" ] "v3" in
  let* c3 = Store.Head.get main in
  let c3_hash = Store.Commit.hash c3 in

  let* () = Store.set_exn ~info main [ "k" ] "v4" in
  let* c4 = Store.Head.get main in

  let* _ = Store.Gc.start_exn repo (Store.Commit.key c4) in
  let* _ = Store.Gc.finalise_exn ~wait:true repo in

  let* c3_after_gc = Store.Commit.of_hash repo c3_hash in
  let c3_after_gc =
    match c3_after_gc with
    | None -> failwith "c3 unexpectedly missing after archival GC"
    | Some c -> c
  in
  Printf.printf "AFTER_GC_LOWER %b\n%!" (commit_is_in_lower ~lower_root c3_after_gc);

  let gen = generation repo in
  let tmp_control =
    Irmin_pack.Layout.V5.Volume.control_gc_tmp ~generation:gen ~root:volume_root
  in
  let* () = Store.Repo.close repo in

  (* Recreate the exact Moment B disk boundary:
     upper store.control already names generation [gen],
     volume.control is still the pre-GC payload,
     volume.[gen].control contains the post-GC payload. *)
  copy_file volume_control tmp_control;
  copy_file old_backup volume_control;

  let old_payload = Result.get_ok (Volume_control.read_payload ~path:volume_control) in
  let new_payload = Result.get_ok (Volume_control.read_payload ~path:tmp_control) in
  Printf.printf "MOMENT_B old_end=%d new_end=%d generation=%d\n%!"
    (Int63.to_int old_payload.end_offset)
    (Int63.to_int new_payload.end_offset) gen;

  let* repo1 = Store.Repo.v (config ~fresh:false ~root ~lower_root) in
  let* first = read_commit repo1 c3_hash in
  pp_read "FIRST_REOPEN_READ" first;
  let* () = Store.Repo.close repo1 in

  let* repo2 = Store.Repo.v (config ~fresh:false ~root ~lower_root) in
  let* second = read_commit repo2 c3_hash in
  pp_read "SECOND_REOPEN_READ" second;
  let* () = Store.Repo.close repo2 in

  match (first, second) with
  | Error _, Ok _ -> Lwt.return_unit
  | Ok _, _ ->
      Lwt.fail_with
        "Moment B did not reproduce: first reopen unexpectedly read archived commit"
  | Error first_error, Error second_error ->
      Lwt.fail_with
        (Printf.sprintf
           "second reopen did not recover: first=%s second=%s"
           first_error second_error)

let () = Lwt_main.run (run ())
