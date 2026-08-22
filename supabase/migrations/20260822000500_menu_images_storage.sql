-- Public menu images with owner/manager-controlled writes.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('menu-images', 'menu-images', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=excluded.public,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

create policy menu_images_insert on storage.objects for insert to authenticated
with check (bucket_id='menu-images' and private.can_manage_menu(
  ((storage.foldername(name))[1])::uuid,
  case when (storage.foldername(name))[2]='business' then null else ((storage.foldername(name))[2])::uuid end
));
create policy menu_images_update on storage.objects for update to authenticated
using (bucket_id='menu-images' and private.can_manage_menu(
  ((storage.foldername(name))[1])::uuid,
  case when (storage.foldername(name))[2]='business' then null else ((storage.foldername(name))[2])::uuid end
));
create policy menu_images_delete on storage.objects for delete to authenticated
using (bucket_id='menu-images' and private.can_manage_menu(
  ((storage.foldername(name))[1])::uuid,
  case when (storage.foldername(name))[2]='business' then null else ((storage.foldername(name))[2])::uuid end
));
