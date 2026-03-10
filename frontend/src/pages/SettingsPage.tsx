import { useEffect, useState } from "react";
import { useAuth } from "@/lib/auth";
import { apiFetch } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { toast } from "sonner";
import type { CustomField } from "@/lib/types";

const ALL_MEDIA_TYPES = [
  { value: "vinyl", label: "Vinyl" },
  { value: "book", label: "Books" },
  { value: "movie", label: "Movies" },
  { value: "show", label: "Shows" },
  { value: "documentary", label: "Documentaries" },
  { value: "audiobook", label: "Audiobooks" },
];

export function SettingsPage() {
  const { user, isAdmin } = useAuth();
  const [profile, setProfile] = useState({
    display_name: user?.display_name ?? "",
    email: user?.email ?? "",
  });
  const [passwords, setPasswords] = useState({
    current: "",
    new: "",
    confirm: "",
  });
  const [isSaving, setIsSaving] = useState(false);

  const handleProfileSave = async () => {
    setIsSaving(true);
    try {
      await apiFetch("/users/me", {
        method: "PATCH",
        body: JSON.stringify(profile),
      });
      toast.success("Profile updated");
    } catch {
      toast.error("Failed to update profile");
    } finally {
      setIsSaving(false);
    }
  };

  const handlePasswordChange = async () => {
    if (passwords.new !== passwords.confirm) {
      toast.error("Passwords do not match");
      return;
    }
    setIsSaving(true);
    try {
      await apiFetch("/users/me", {
        method: "PATCH",
        body: JSON.stringify({ password: passwords.new }),
      });
      toast.success("Password updated");
      setPasswords({ current: "", new: "", confirm: "" });
    } catch {
      toast.error("Failed to update password");
    } finally {
      setIsSaving(false);
    }
  };

  const toggleTheme = () => {
    document.documentElement.classList.toggle("dark");
    const isDark = document.documentElement.classList.contains("dark");
    localStorage.setItem("theme", isDark ? "dark" : "light");
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Settings</h1>
        <p className="text-muted-foreground">
          Manage your account and preferences.
        </p>
      </div>

      <Tabs defaultValue="profile">
        <TabsList>
          <TabsTrigger value="profile">Profile</TabsTrigger>
          <TabsTrigger value="appearance">Appearance</TabsTrigger>
          {isAdmin && <TabsTrigger value="admin">Admin</TabsTrigger>}
        </TabsList>

        <TabsContent value="profile" className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Profile Information</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div className="space-y-2">
                  <Label>Display Name</Label>
                  <Input
                    value={profile.display_name}
                    onChange={(e) =>
                      setProfile((prev) => ({
                        ...prev,
                        display_name: e.target.value,
                      }))
                    }
                  />
                </div>
                <div className="space-y-2">
                  <Label>Email</Label>
                  <Input
                    type="email"
                    value={profile.email}
                    onChange={(e) =>
                      setProfile((prev) => ({
                        ...prev,
                        email: e.target.value,
                      }))
                    }
                  />
                </div>
              </div>
              <div className="space-y-2">
                <Label>Username</Label>
                <Input value={user?.username ?? ""} disabled />
                <p className="text-xs text-muted-foreground">
                  Username cannot be changed.
                </p>
              </div>
              <Button onClick={handleProfileSave} disabled={isSaving}>
                {isSaving ? "Saving..." : "Save Profile"}
              </Button>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle className="text-base">Change Password</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
                <div className="space-y-2">
                  <Label>Current Password</Label>
                  <Input
                    type="password"
                    value={passwords.current}
                    onChange={(e) =>
                      setPasswords((prev) => ({
                        ...prev,
                        current: e.target.value,
                      }))
                    }
                  />
                </div>
                <div className="space-y-2">
                  <Label>New Password</Label>
                  <Input
                    type="password"
                    value={passwords.new}
                    onChange={(e) =>
                      setPasswords((prev) => ({
                        ...prev,
                        new: e.target.value,
                      }))
                    }
                  />
                </div>
                <div className="space-y-2">
                  <Label>Confirm Password</Label>
                  <Input
                    type="password"
                    value={passwords.confirm}
                    onChange={(e) =>
                      setPasswords((prev) => ({
                        ...prev,
                        confirm: e.target.value,
                      }))
                    }
                  />
                </div>
              </div>
              <Button onClick={handlePasswordChange} disabled={isSaving}>
                Update Password
              </Button>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="appearance">
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Theme</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <p className="text-sm text-muted-foreground">
                Toggle between dark and light mode.
              </p>
              <Button variant="outline" onClick={toggleTheme}>
                Toggle Theme
              </Button>
            </CardContent>
          </Card>
        </TabsContent>

        {isAdmin && (
          <TabsContent value="admin" className="space-y-6">
            <AdminPanel />
            <CustomFieldsPanel />
          </TabsContent>
        )}
      </Tabs>
    </div>
  );
}

function AdminPanel() {
  const [users, setUsers] = useState<
    {
      id: string;
      username: string;
      display_name: string;
      role: string;
      is_active: boolean;
    }[]
  >([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    apiFetch<typeof users>("/users/")
      .then(setUsers)
      .catch(() => {})
      .finally(() => setIsLoading(false));
  }, []);

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">User Management</CardTitle>
      </CardHeader>
      <CardContent>
        {isLoading ? (
          <p className="text-sm text-muted-foreground">Loading users...</p>
        ) : users.length === 0 ? (
          <p className="text-sm text-muted-foreground">No users found.</p>
        ) : (
          <div className="space-y-3">
            {users.map((u) => (
              <div
                key={u.id}
                className="flex items-center justify-between rounded-lg border p-3"
              >
                <div>
                  <p className="text-sm font-medium">{u.display_name}</p>
                  <p className="text-xs text-muted-foreground">
                    @{u.username}
                  </p>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-xs capitalize text-muted-foreground">
                    {u.role}
                  </span>
                  {!u.is_active && (
                    <span className="text-xs text-destructive">Inactive</span>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </CardContent>
    </Card>
  );
}

function CustomFieldsPanel() {
  const [fields, setFields] = useState<CustomField[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [showAdd, setShowAdd] = useState(false);
  const [showDelete, setShowDelete] = useState<CustomField | null>(null);
  const [form, setForm] = useState({
    name: "",
    field_key: "",
    field_type: "text",
    options: "",
    media_types: [] as string[],
  });
  const [isSubmitting, setIsSubmitting] = useState(false);

  const fetchFields = async () => {
    try {
      const data = await apiFetch<CustomField[]>("/custom-fields/");
      setFields(data);
    } catch {
      // ignore
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchFields();
  }, []);

  const autoKey = (name: string) =>
    name
      .toLowerCase()
      .replace(/[^a-z0-9\s]/g, "")
      .replace(/\s+/g, "_")
      .replace(/^_+|_+$/g, "");

  const handleCreate = async () => {
    if (!form.name.trim() || !form.field_key.trim()) {
      toast.error("Name and key are required");
      return;
    }
    setIsSubmitting(true);
    try {
      await apiFetch("/custom-fields/", {
        method: "POST",
        body: JSON.stringify({
          name: form.name.trim(),
          field_key: form.field_key.trim(),
          field_type: form.field_type,
          options:
            form.field_type === "select" && form.options
              ? form.options
                  .split(",")
                  .map((o) => o.trim())
                  .filter(Boolean)
              : [],
          media_types: form.media_types,
        }),
      });
      toast.success("Custom field created");
      setShowAdd(false);
      setForm({
        name: "",
        field_key: "",
        field_type: "text",
        options: "",
        media_types: [],
      });
      await fetchFields();
    } catch {
      toast.error("Failed to create field. Key may already exist.");
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDelete = async (field: CustomField) => {
    try {
      await apiFetch(`/custom-fields/${field.id}`, { method: "DELETE" });
      toast.success(`Removed "${field.name}"`);
      setShowDelete(null);
      await fetchFields();
    } catch {
      toast.error("Failed to delete field");
    }
  };

  const toggleMediaType = (type: string) => {
    setForm((prev) => ({
      ...prev,
      media_types: prev.media_types.includes(type)
        ? prev.media_types.filter((t) => t !== type)
        : [...prev.media_types, type],
    }));
  };

  return (
    <>
      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle className="text-base">Custom Fields</CardTitle>
          <Button size="sm" onClick={() => setShowAdd(true)}>
            Add Field
          </Button>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-muted-foreground mb-4">
            Define custom metadata fields that appear on item detail pages. Values are stored in each item's metadata.
          </p>
          {isLoading ? (
            <p className="text-sm text-muted-foreground">Loading...</p>
          ) : fields.length === 0 ? (
            <p className="text-sm text-muted-foreground">
              No custom fields defined yet.
            </p>
          ) : (
            <div className="space-y-3">
              {fields.map((f) => (
                <div
                  key={f.id}
                  className="flex items-center justify-between rounded-lg border p-3"
                >
                  <div className="space-y-1">
                    <div className="flex items-center gap-2">
                      <p className="text-sm font-medium">{f.name}</p>
                      <Badge variant="outline" className="text-[10px]">
                        {f.field_type}
                      </Badge>
                    </div>
                    <p className="text-xs text-muted-foreground font-mono">
                      {f.field_key}
                    </p>
                    {f.media_types.length > 0 && (
                      <div className="flex gap-1 flex-wrap">
                        {f.media_types.map((t) => (
                          <Badge
                            key={t}
                            variant="secondary"
                            className="text-[10px] capitalize"
                          >
                            {t}
                          </Badge>
                        ))}
                      </div>
                    )}
                    {f.field_type === "select" && f.options.length > 0 && (
                      <p className="text-xs text-muted-foreground">
                        Options: {f.options.join(", ")}
                      </p>
                    )}
                  </div>
                  <Button
                    variant="ghost"
                    size="sm"
                    className="text-destructive hover:text-destructive"
                    onClick={() => setShowDelete(f)}
                  >
                    Delete
                  </Button>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Add custom field dialog */}
      <Dialog open={showAdd} onOpenChange={setShowAdd}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Add Custom Field</DialogTitle>
          </DialogHeader>
          <div className="space-y-4">
            <div className="space-y-2">
              <Label>Display Name</Label>
              <Input
                placeholder="e.g. Vinyl Color"
                value={form.name}
                onChange={(e) => {
                  const name = e.target.value;
                  setForm((prev) => ({
                    ...prev,
                    name,
                    field_key: prev.field_key === autoKey(prev.name) ? autoKey(name) : prev.field_key,
                  }));
                }}
              />
            </div>
            <div className="space-y-2">
              <Label>Field Key</Label>
              <Input
                placeholder="e.g. vinyl_color"
                value={form.field_key}
                onChange={(e) =>
                  setForm((prev) => ({ ...prev, field_key: e.target.value }))
                }
                className="font-mono text-sm"
              />
              <p className="text-xs text-muted-foreground">
                Lowercase, underscores only. Used as the metadata key.
              </p>
            </div>
            <div className="space-y-2">
              <Label>Field Type</Label>
              <Select
                value={form.field_type}
                onValueChange={(v) =>
                  setForm((prev) => ({ ...prev, field_type: v ?? "text" }))
                }
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="text">Text</SelectItem>
                  <SelectItem value="number">Number</SelectItem>
                  <SelectItem value="select">Select (Dropdown)</SelectItem>
                </SelectContent>
              </Select>
            </div>
            {form.field_type === "select" && (
              <div className="space-y-2">
                <Label>Options (comma-separated)</Label>
                <Input
                  placeholder="e.g. Red, Blue, Green, Black"
                  value={form.options}
                  onChange={(e) =>
                    setForm((prev) => ({ ...prev, options: e.target.value }))
                  }
                />
              </div>
            )}
            <div className="space-y-2">
              <Label>Applies To</Label>
              <p className="text-xs text-muted-foreground">
                Select which media types this field applies to. Leave empty for
                all types.
              </p>
              <div className="flex flex-wrap gap-2">
                {ALL_MEDIA_TYPES.map((t) => (
                  <Button
                    key={t.value}
                    type="button"
                    variant={
                      form.media_types.includes(t.value)
                        ? "secondary"
                        : "outline"
                    }
                    size="sm"
                    onClick={() => toggleMediaType(t.value)}
                  >
                    {t.label}
                  </Button>
                ))}
              </div>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setShowAdd(false)}>
              Cancel
            </Button>
            <Button onClick={handleCreate} disabled={isSubmitting}>
              {isSubmitting ? "Creating..." : "Create Field"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete confirmation dialog */}
      <Dialog
        open={!!showDelete}
        onOpenChange={() => setShowDelete(null)}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Delete custom field?</DialogTitle>
          </DialogHeader>
          <p className="text-sm text-muted-foreground">
            This will remove the "{showDelete?.name}" field definition.
            Existing metadata values on items will not be deleted.
          </p>
          <DialogFooter>
            <Button variant="outline" onClick={() => setShowDelete(null)}>
              Cancel
            </Button>
            <Button
              variant="destructive"
              onClick={() => showDelete && handleDelete(showDelete)}
            >
              Delete
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}
