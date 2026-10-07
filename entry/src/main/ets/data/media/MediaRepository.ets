import { ReferenceImage } from '../../model/Planning';
import { common } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { PhotoAsset, ManagedMedia } from '../../model/Entities';

export class MediaRepository {
  static imageUri(path: string): string {
    if (!path) { return ''; }
    return path.startsWith('file://') ? path : fileUri.getUriFromPath(path);
  }
  private context: common.Context;
  private mediaRoot: string;
  constructor(context: common.Context, testRoot?: string) {
    this.context = context;
    if (testRoot && (!testRoot.startsWith(context.filesDir + '/verification-') || testRoot.slice(context.filesDir.length + 1).includes('/'))) { throw new Error('Invalid verification media path'); }
    this.mediaRoot = testRoot || context.filesDir + '/media';
  }
  async exists(media: ManagedMedia): Promise<boolean> { return !!media.localPath && !!media.thumbnailPath && await fs.access(media.localPath) && await fs.access(media.thumbnailPath); }
  private cacheRoot(testRoot?: string): string {
    if (testRoot && (!testRoot.startsWith(this.context.cacheDir + '/verification-') || testRoot.slice(this.context.cacheDir.length + 1).includes('/'))) { throw new Error('Invalid verification cache path'); }
    return testRoot || this.context.cacheDir;
  }
  async cacheSize(testRoot?: string): Promise<number> {
    const root = this.cacheRoot(testRoot);
    if (!(await fs.access(root))) { return 0; }
    return this.directorySize(root);
  }
  private async directorySize(root: string): Promise<number> {
    let size = 0;
    for (const name of await fs.listFile(root)) {
      const path = root + '/' + name;
      const stat = await fs.stat(path);
      size += stat.isDirectory() ? await this.directorySize(path) : stat.size;
    }
    return size;
  }
  async clearCache(testRoot?: string): Promise<void> {
    const root = this.cacheRoot(testRoot);
    if (!(await fs.access(root))) { return; }
    for (const name of await fs.listFile(root)) {
      const path = root + '/' + name;
      if ((await fs.stat(path)).isDirectory()) { await fs.rmdir(path); } else { await fs.unlink(path); }
    }
  }
  async select(): Promise<string[]> {
    const picker = new photoAccessHelper.PhotoViewPicker();
    const result = await picker.select({ MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE, maxSelectNumber: 20 });
    return result.photoUris;
  }
  async import(uri: string, projectId: string): Promise<PhotoAsset> {
    const dir = this.mediaRoot;
    if (!(await fs.access(dir))) { await fs.mkdir(dir, true); }
    const photo = new PhotoAsset(); photo.projectId = projectId; photo.sourceUri = uri;
    photo.localPath = dir + '/' + photo.id + '.original';
    photo.thumbnailPath = dir + '/' + photo.id + '.jpg';
    const sourceFile = await fs.open(uri, fs.OpenMode.READ_ONLY);
    try {
      const stat = await fs.stat(sourceFile.fd);
      if (stat.size > 100 * 1024 * 1024) { throw new Error('单张照片最大支持 100 MB'); }
      await fs.copyFile(sourceFile.fd, photo.localPath);
      const source = image.createImageSource(sourceFile.fd);
      try {
        const info = await source.getImageInfo();
        const ratio = Math.min(1, 480 / Math.max(info.size.width, info.size.height));
        const pixel = await source.createPixelMap({ desiredSize: { width: Math.max(1, Math.round(info.size.width * ratio)), height: Math.max(1, Math.round(info.size.height * ratio)) } });
        try {
          const packer = image.createImagePacker();
          try {
            const packed = await packer.packToData(pixel, { format: 'image/jpeg', quality: 80 });
            const thumb = await fs.open(photo.thumbnailPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
            try { await fs.write(thumb.fd, packed); } finally { await fs.close(thumb); }
          } finally { packer.release(); }
        } finally { pixel.release(); }
      } finally { source.release(); }
      return photo;
    } catch (error) { await this.remove(photo); throw error as Error; } finally { await fs.close(sourceFile); }
  }
  async importReference(uri: string, projectId: string, characterId: string): Promise<ReferenceImage> {
    const media = await this.import(uri, projectId);
    const r = new ReferenceImage(); r.id = media.id; r.projectId = projectId; r.characterId = characterId; r.sourceUri = media.sourceUri; r.localPath = media.localPath; r.thumbnailPath = media.thumbnailPath; return r;
  }
  async remove(photo: ManagedMedia): Promise<void> {
    for (const path of [photo.localPath, photo.thumbnailPath]) {
      if (path.startsWith(this.mediaRoot + '/')) { try { await fs.unlink(path); } catch (error) {} }
    }
  }
  async collect(photos: PhotoAsset[], references: ReferenceImage[] = []): Promise<void> {
    const dir = this.mediaRoot;
    const keep: string[] = [];
    photos.forEach((p: PhotoAsset) => { keep.push(p.localPath); keep.push(p.thumbnailPath); });
    references.forEach((r: ReferenceImage) => { keep.push(r.localPath); keep.push(r.thumbnailPath); });
    try {
      const names = await fs.listFile(dir);
      for (const name of names) { const path = dir + '/' + name; if (!keep.includes(path)) { await fs.unlink(path); } }
    } catch (error) { /* A fresh installation has no media directory. Retry on next launch. */ }
  }
}
