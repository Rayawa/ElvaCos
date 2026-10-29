import { handleSheetBack, handleSheetKey } from '../../ui/sheet/sheet';

// bindSheet content has its own native focus scope outside the navigation tree.
@ComponentV2
export struct SheetContent {
    @BuilderParam content: () => void = this.emptyContent;
    @Event shortcut: (event: KeyEvent) => boolean = () => false;

    @Builder emptyContent() {
        Blank()
    }

    build() {
        Column() {
            this.content()
        }.width('100%').height('100%')
            .onKeyPreIme((event: KeyEvent): boolean => handleSheetKey(event) || this.shortcut(event))
            .keyboardShortcut(FunctionKey.ESC, [], (): void => {
                handleSheetBack();
            })
    }
}
