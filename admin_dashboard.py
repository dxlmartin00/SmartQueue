from kivymd.uix.screen import MDScreen
from kivymd.uix.boxlayout import MDBoxLayout
from kivymd.uix.card import MDCard
from kivymd.uix.label import MDLabel
from kivymd.uix.button import MDRaisedButton
from kivymd.uix.list import OneLineListItem
from kivymd.uix.scrollview import MDScrollView
from kivymd.uix.toolbar import MDTopAppBar
from kivymd.uix.snackbar import Snackbar
from kivy.clock import Clock
from kivy.metrics import dp


class AdminDashboardScreen(MDScreen):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.queue_system = None
        self.build_ui()
        self.update_event = None
    
    def set_queue_system(self, queue_system):
        self.queue_system = queue_system
    
    def build_ui(self):
        layout = MDBoxLayout(orientation='vertical')
        
        # Top bar
        toolbar = MDTopAppBar(
            title="Admin Dashboard",
            right_action_items=[["logout", lambda x: self.logout()]]
        )
        
        # Main content
        scroll = MDScrollView()
        self.content = MDBoxLayout(orientation='vertical', spacing=dp(20), padding=dp(20))
        self.content.bind(minimum_height=self.content.setter('height'))
        
        # Stats card
        self.stats_card = MDCard(
            size_hint_y=None,
            height=dp(100),
            padding=dp(15),
            elevation=2
        )
        self.stats_layout = MDBoxLayout(orientation='vertical')
        self.stats_card.add_widget(self.stats_layout)
        
        self.content.add_widget(self.stats_card)
        
        scroll.add_widget(self.content)
        layout.add_widget(toolbar)
        layout.add_widget(scroll)
        
        self.add_widget(layout)
    
    def on_enter(self):
        self.update_dashboard()
        self.update_event = Clock.schedule_interval(self.update_dashboard, 3)  # Update every 3 seconds
    
    def on_leave(self):
        if self.update_event:
            self.update_event.cancel()
    
    def update_dashboard(self, *args):
        if not self.queue_system:
            return
            
        # Clear existing queue widgets (keep stats card)
        while len(self.content.children) > 1:
            self.content.remove_widget(self.content.children[0])
        
        # Update stats
        self.stats_layout.clear_widgets()
        stats = self.queue_system.queue_stats
        stats_text = f"Total Served Today: {stats['total_served']}"
        stats_label = MDLabel(
            text=stats_text,
            theme_text_color="Primary",
            halign="center"
        )
        self.stats_layout.add_widget(stats_label)
        
        # Queue overview
        overview = self.queue_system.get_queue_overview()
        
        for queue_name, queue_info in overview.items():
            # Queue header
            queue_card = MDCard(
                size_hint_y=None,
                height=dp(60),
                padding=dp(15),
                elevation=1
            )
            
            header_layout = MDBoxLayout()
            queue_label = MDLabel(
                text=f"{queue_name} ({queue_info['count']} waiting)",
                theme_text_color="Primary",
                halign="left"
            )
            
            call_btn = MDRaisedButton(
                text="Call Next",
                size_hint_x=None,
                width=dp(120),
                disabled=queue_info['count'] == 0,
                on_release=lambda x, qn=queue_name: self.call_next_customer(qn)
            )
            
            header_layout.add_widget(queue_label)
            header_layout.add_widget(call_btn)
            queue_card.add_widget(header_layout)
            
            self.content.add_widget(queue_card)
            
            # Customer list
            if queue_info['customers']:
                for i, customer in enumerate(queue_info['customers'][:5]):  # Show first 5
                    customer_item = OneLineListItem(
                        text=f"{i+1}. {customer['name']} - {customer['wait_time']}min" + 
                             (" [PRIORITY]" if customer['priority'] else "")
                    )
                    self.content.add_widget(customer_item)
                
                if len(queue_info['customers']) > 5:
                    more_label = MDLabel(
                        text=f"... and {len(queue_info['customers']) - 5} more",
                        theme_text_color="Hint",
                        size_hint_y=None,
                        height=dp(30)
                    )
                    self.content.add_widget(more_label)
    
    def call_next_customer(self, queue_name):
        if not self.queue_system:
            return
            
        customer = self.queue_system.call_next_customer(queue_name)
        if customer:
            self.show_message(f"Called: {customer['full_name']} from {queue_name}")
            self.update_dashboard()
        else:
            self.show_message("No customers in queue")
    
    def logout(self):
        if self.queue_system:
            self.queue_system.current_user = None
            self.queue_system.user_role = None
        self.manager.current = 'login'
    
    def show_message(self, text):
        try:
            snackbar = Snackbar()
            snackbar.text = text
            snackbar.open()
        except Exception as e:
            print(f"Snackbar error: {e}")
            print(f"Message: {text}")