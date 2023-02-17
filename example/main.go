package main

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/kolide/systray"
)

func main() {
	onExit := func() {
		now := time.Now()
		fmt.Println("Exit at", now.String())
	}

	systray.Run(onReady, onExit)
}

// func addQuitItem() {
// 	mQuit := systray.AddMenuItem("Quit", "Quit the whole app")
// 	mQuit.Enable()
// 	go func() {
// 		<-mQuit.ClickedCh
// 		fmt.Println("Requesting quit")
// 		systray.Quit()
// 		fmt.Println("Finished quitting")
// 	}()
// }

func onReady() {
	// systray.SetTemplateIcon(icon.Data, icon.Data)
	// systray.SetTitle("Icon c")
	// systray.SetTooltip("Lantern")
	// addQuitItem()

	path, err := os.Getwd()
	// handle err

	systray.SetTitle("Kolide Icons")
	systray.SetTooltip("Kolide icon chooser")

	fmt.Println("Finding PNGs in dir: " + path)

	files, err := os.ReadDir(path)
	if err != nil {
		log.Fatal(err)
	}

	for _, f := range files {
		if strings.HasSuffix(f.Name(), ".png") {
			name := f.Name()
			action := func() {
				systray.SetTitle("")
				f1Bytes, err := os.ReadFile(filepath.Join(path, name))
				if err != nil {
					return
				}
				systray.SetTemplateIcon(f1Bytes, f1Bytes)
				fmt.Println("Setting menu bar icon to: " + name)
			}
			item := systray.AddMenuItem(f.Name(), "")
			makeActionHandler(item, action)
		}
	}
	/*
		for _, e := range files {
			if strings.HasSuffix(e.Name(), ".png") {
				f1Bytes, err := os.ReadFile(filepath.Join(path, e.Name()))
				if err != nil {
					// return false, fmt.Errorf("reading f1 (%s): %w", f1, err)
				}
				systray.SetTemplateIcon(f1Bytes, f1Bytes)
				fmt.Println("Setting menu bar icon to: " + e.Name())

				time.Sleep(time.Second * 2)

			}
		}
	*/
	/*
	   // We can manipulate the systray in other goroutines

	   	go func() {
	   		systray.SetTemplateIcon(icon.Data, icon.Data)
	   		systray.SetTitle("Awesome App")
	   		systray.SetTooltip("Pretty awesome棒棒嗒")
	   		mChange := systray.AddMenuItem("Change Me", "Change Me")
	   		mChecked := systray.AddMenuItemCheckbox("Checked", "Check Me", true)
	   		mEnabled := systray.AddMenuItem("Enabled", "Enabled")
	   		// Sets the icon of a menu item. Only available on Mac.
	   		mEnabled.SetTemplateIcon(icon.Data, icon.Data)

	   		systray.AddMenuItem("Ignored", "Ignored")

	   		subMenuTop := systray.AddMenuItem("SubMenuTop", "SubMenu Test (top)")
	   		subMenuMiddle := subMenuTop.AddSubMenuItem("SubMenuMiddle", "SubMenu Test (middle)")
	   		subMenuBottom := subMenuMiddle.AddSubMenuItemCheckbox("SubMenuBottom - Toggle Panic!", "SubMenu Test (bottom) - Hide/Show Panic!", false)
	   		subMenuBottom2 := subMenuMiddle.AddSubMenuItem("SubMenuBottom - Panic!", "SubMenu Test (bottom)")

	   		systray.AddSeparator()
	   		mToggle := systray.AddMenuItem("Toggle", "Toggle some menu items")
	   		shown := true
	   		toggle := func() {
	   			if shown {
	   				subMenuBottom.Check()
	   				subMenuBottom2.Hide()
	   				mEnabled.Hide()
	   				shown = false
	   			} else {
	   				subMenuBottom.Uncheck()
	   				subMenuBottom2.Show()
	   				mEnabled.Show()
	   				shown = true
	   			}
	   		}
	   		mReset := systray.AddMenuItem("Reset", "Reset all items")

	   		for {
	   			select {
	   			case <-mChange.ClickedCh:
	   				mChange.SetTitle("I've Changed")
	   			case <-mChecked.ClickedCh:
	   				if mChecked.Checked() {
	   					mChecked.Uncheck()
	   					mChecked.SetTitle("Unchecked")
	   				} else {
	   					mChecked.Check()
	   					mChecked.SetTitle("Checked")
	   				}
	   			case <-mEnabled.ClickedCh:
	   				mEnabled.SetTitle("Disabled")
	   				mEnabled.Disable()
	   			case <-subMenuBottom2.ClickedCh:
	   				panic("panic button pressed")
	   			case <-subMenuBottom.ClickedCh:
	   				toggle()
	   			case <-mReset.ClickedCh:
	   				systray.ResetMenu()
	   				addQuitItem()
	   			case <-mToggle.ClickedCh:
	   				toggle()
	   			}
	   		}
	   	}()
	*/
}

// makeActionHandler creates a handler to execute the desired action when a menu item is clicked
func makeActionHandler(item *systray.MenuItem, action func()) {
	// if ap == nil {
	// 	// No action to handle
	// 	return
	// }

	// Create and hold on to a done channel for each action, so we don't leak goroutines
	done := make(chan struct{})
	// doneChans = append(doneChans, done)

	go func() {
		for {
			select {
			case <-item.ClickedCh:
				// Menu item was clicked
				action()
			case <-done:
				// Menu item is going away
				return
			}
		}
	}()
}
