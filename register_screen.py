from kivymd.uix.screen import MDScreen
from kivymd.uix.boxlayout import MDBoxLayout
from kivymd.uix.label import MDLabel
from kivymd.uix.button import MDRaisedButton, MDIconButton
from kivymd.uix.textfield import MDTextField
from kivymd.uix.snackbar import Snackbar
from kivy.metrics import dp
from kivy.clock import Clock


class RegisterScreen(MDScreen):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.queue_system = None
        self.build_ui()
    
    def set_queue_system(self, queue_system):
        self.queue_system = queue_system
    
    def build_ui(self):
        layout = MDBoxLayout(orientation='vertical', spacing=dp(20), padding=dp(30))
        
        # Back button and title
        top_layout = MDBoxLayout(size_hint_y=None, height=dp(50))
        back_btn = MDIconButton(
            icon="arrow-left",
            on_release=self.go_back
        )
        title = MDLabel(
            text="Create Account",
            theme_text_color="Primary",
            halign="center"
        )
        top_layout.add_widget(back_btn)
        top_layout.add_widget(title)
        
        # Registration form
        self.username_field = MDTextField(
            hint_text="Username",
            icon_right="account",
            size_hint_y=None,
            height=dp(50)
        )
        
        self.password_field = MDTextField(
            hint_text="Password",
            icon_right="lock",
            password=True,
            size_hint_y=None,
            height=dp(50)
        )
        
        self.fullname_field = MDTextField(
            hint_text="Full Name",
            icon_right="account-circle",
            size_hint_y=None,
            height=dp(50)
        )
        
        self.phone_field = MDTextField(
            hint_text="Phone Number",
            icon_right="phone",
            size_hint_y=None,
            height=dp(50)
        )
        
        register_btn = MDRaisedButton(
            text="CREATE ACCOUNT",
            size_hint_y=None,
            height=dp(40),
            on_release=self.register
        )
        
        layout.add_widget(top_layout)
        layout.add_widget(self.username_field)
        layout.add_widget(self.password_field)
        layout.add_widget(self.fullname_field)
        layout.add_widget(self.phone_field)
        layout.add_widget(register_btn)
        
        self.add_widget(layout)
    
    def register(self, *args):
        try:
            username = self.username_field.text.strip() if self.username_field.text else ""
            password = self.password_field.text.strip() if self.password_field.text else ""
            fullname = self.fullname_field.text.strip() if self.fullname_field.text else ""
            phone = self.phone_field.text.strip() if self.phone_field.text else ""
            
            if not all([username, password, fullname, phone]):
                self.show_message("Please fill in all fields")
                return
            
            if len(username) < 3:
                self.show_message("Username must be at least 3 characters")
                return
                
            if len(password) < 4:
                self.show_message("Password must be at least 4 characters")
                return
            
            success = self.queue_system.register_user(username, password, fullname, phone)
            if success:
                self.show_message("Account created successfully!")
                # Clear fields
                self.username_field.text = ""
                self.password_field.text = ""
                self.fullname_field.text = ""
                self.phone_field.text = ""
                # Navigate back after a short delay
                Clock.schedule_once(lambda dt: self.go_back(), 1.5)
            else:
                self.show_message("Username already exists")
        except Exception as e:
            self.show_message(f"Registration error: {str(e)}")
            print(f"Registration error: {e}")
    
    def go_back(self, *args):
        self.manager.current = 'login'
    
    def show_message(self, text):
        try:
            snackbar = Snackbar()
            snackbar.text = text
            snackbar.open()
        except Exception as e:
            print(f"Snackbar error: {e}")
            print(f"Message: {text}")