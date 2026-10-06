// Pixel values supplied by the main window; pages convert them using their UIContext.
@ObservedV2
export class WindowInsets {
  @Trace top: number = 0;
  @Trace bottom: number = 0;
  @Trace left: number = 0;
  @Trace right: number = 0;
}
export const windowInsets: WindowInsets = new WindowInsets();
