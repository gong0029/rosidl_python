
#include <Python.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <pthread.h>

#include "__common.h"

__thread pthread_key_t key = -1;

int stringHash1(char* str) {
    int i;
    int r = 0;
    for (i = 0; str[i] != '\0'; i++) {
        r += str[i];
    }
    return r;
}

int stringHash2(char* str) {
    int i;
    int r = 0;
    for (i = 0; str[i] != '\0'; i++) {
        r += (i + 1) * str[i];
    }
    return r;
}

int getHashVal(char* str) {

    int key_size = strlen(str)+1;

    char* hashKey = (char*) malloc(sizeof(char) * key_size);
    memcpy(hashKey, str, strlen(str));
    hashKey[key_size-1] = '\0';
    
    int hashVal = stringHash2(hashKey);
    free(hashKey);
    
    return hashVal;

}

void _initMap(struct HashMap* ht, int tableSize) {
    int index;
    if (ht == NULL) {
        return;
    }
    ht->table = (HashLink**) malloc(sizeof(HashLink*) * tableSize);
    ht->tableSize = tableSize;
    ht->count = 0;
    for (index = 0; index < tableSize; index++) {
        ht->table[index] = 0;
    }
}

struct HashMap* createMap(int tableSize) {
    HashMap* ht;
    assert(tableSize > 0);
    ht = malloc(sizeof(HashMap));
    assert(ht != 0);
    _initMap(ht, tableSize);
    return ht;
}

void _freeMap(struct HashMap* ht) {
    int i = 0;
    struct HashLink * currLink, *nextLink;

    for (i = 0; i < ht->tableSize; i++) {
        if (ht->count == 0) {
            break;
        }
        currLink = ht->table[i];
        if (currLink != 0) {
            nextLink = currLink->next;
        }
        //Scan entire linked list
        while (currLink != 0) {
            if(strlen(currLink->key) >5) {
                char prefix[5];
                memcpy(prefix,currLink->key,5);
                if(strcmp(prefix,"class") == 0) {
                    PyObject * pymessage_class = (PyObject*) currLink->value;
                    Py_DECREF(pymessage_class);
                }
            }
            currLink->key = 0;
            currLink->value = 0;
            //Free hashLink and decrement hashLink counter
            free(currLink);
            ht->count--;

            //Move to next link
            currLink = nextLink;
            if (currLink != 0) {
                nextLink = currLink->next;
            }
        }
    }
    //Free the dynamically allocated hashLink ** in hashMap struct
    free(ht->table);
}

void deleteMap(HashMap* ht) {
    assert(ht != 0);
    _freeMap(ht);
    //free the hashMap struct
    free(ht);
}

void _setTableSize(struct HashMap* ht, int newTableSize) {
    int i = 0;
    struct HashMap * newHM, *oldHM;
    struct HashLink* currLink;

    newHM = createMap(newTableSize);
    oldHM = ht;

    //Iterate through all hashLinks in old hashMap and copy them into new HashMap
    while (i < ht->tableSize) {
        currLink = ht->table[i];
        while (currLink != 0) {
            insertMap(newHM, currLink->key, currLink->value, currLink->hashVal);
            currLink = currLink->next;
        }
        i++;
    }

    //Replace hashMap pointer with new HashMap and free old HashMap
    _freeMap(oldHM);
    ht->table = newHM->table;
    ht->tableSize = newHM->tableSize;
    ht->count = newHM->count;
}

void insertMap(struct HashMap* ht, KeyType k, ValueType v, int hashVal) {
    int hashIndex;
    struct HashLink * newHashLink = (struct HashLink*) malloc(sizeof(struct HashLink));
    char* newKeyType = (char*) malloc(strlen(k)+1);

    hashIndex = hashVal % ht->tableSize;

    //ensure hashIndex is positive
    if(hashIndex < 0) {
        hashIndex += ht->tableSize;
    }

    assert(newHashLink);

    //remove duplicate keys so new key replaces old key
    if(containsKey(ht,hashVal)) {
        removeKey(ht,hashVal);
    }

    //Initialize new hashLink and add to appropriate hash index
    strcpy(newKeyType, k);

    newHashLink->key = newKeyType;
    newHashLink->value = v;
    newHashLink->hashVal = hashVal;
    newHashLink->next = ht->table[hashIndex];
    ht->table[hashIndex] = newHashLink;

    ht->count++;

    //Test table load and resize if necessary
    if(tableLoad(ht) >= LOAD_FACTOR_THRESHOLD) {
        _setTableSize(ht, ht->tableSize*2);
    }
}

ValueType atMap(struct HashMap* ht, int hashVal) {
    int hashIndex;
    struct HashLink* currLink;

    hashIndex = hashVal % ht->tableSize;

    currLink = ht->table[hashIndex];;
    while(currLink != 0) {
        if(hashVal == currLink->hashVal) {
            return currLink->value;
        }
        currLink = currLink->next;
    }

    //if search of linked list did not return a match, return NULL
    return NULL;
}

int containsKey(struct HashMap* ht, int hashVal) {
    int hashIndex;
    struct HashLink* currLink;

    hashIndex = hashVal % ht->tableSize;
  
    currLink = ht->table[hashIndex];
    while(currLink != 0) {
        if(hashVal == currLink->hashVal) {
            return 1;
        }
        currLink = currLink->next;
    }

    return 0;
}

void removeKey(struct HashMap* ht, int hashVal) {
    int hashIndex;
    struct HashLink * lastLink, * currLink;

    hashIndex = hashVal % ht->tableSize;

    currLink = ht->table[hashIndex];
    lastLink = currLink;

    //check each member in linked list for the requested KeyType and return value
    while(currLink != 0) {
        if(hashVal == currLink->hashVal) {
            if(lastLink == currLink) {
                lastLink = currLink->next;
                ht->table[hashIndex] = lastLink;
            } else {
                lastLink->next = currLink->next;
            }

            //TODO
            currLink->value = NULL;
            free(currLink);
            ht->count--;
            break;
        }

        currLink = currLink->next;
    }
}

int size(struct HashMap *ht) {
    return ht->count;
}

int capacity(struct HashMap *ht) {
    return ht->tableSize;
}

float tableLoad(struct HashMap *ht) {
    float loadRatio = 0.0;

    loadRatio = (float) ht->count / (float) ht->tableSize;

    return loadRatio;
}


//===============================================================================


void dest_tid(void* v_tid) {
    HashMap* tid = (HashMap*) v_tid;
    deleteMap(tid);
}

convert_from_py_signature get_convert_from_py_signature(char* module_name,
        char* class_name,int hashVal) {

    void* data = pthread_getspecific(key);
    if (data == NULL) {
        int rc = pthread_key_create(&key, dest_tid);
        assert(rc == 0);
        HashMap* tid = createMap(10);
        rc = pthread_setspecific(key, tid);
        assert(rc == 0);
    }

    data = pthread_getspecific(key);
    assert(data != NULL);

    HashMap* hm = (HashMap*) data;

    char* prefix = "c_from_py_";
    int key_size = strlen(module_name) + strlen(class_name) + strlen(prefix)+1;

    convert_from_py_signature convert_from_py = NULL;

    if (containsKey(hm, hashVal)) {
        convert_from_py = (convert_from_py_signature) atMap(hm, hashVal);
        return convert_from_py;
    } else {
    
        char* hashKey = (char*) malloc(sizeof(char) * key_size);
        memcpy(hashKey, prefix, strlen(prefix));
        memcpy(&hashKey[strlen(prefix)], module_name, strlen(module_name));
        memcpy(&hashKey[strlen(prefix) + strlen(module_name)], class_name,
                strlen(class_name));
        hashKey[key_size-1] = '\0';
    
        printf("--------------------------------get_convert_from_py_signature containsKey:%s\n",hashKey);
        
        PyObject * msg_module = PyImport_ImportModule(module_name);
        if (!msg_module) {
            return NULL;
        }

        PyObject * msg_class = PyObject_GetAttrString(msg_module, class_name);
        Py_DECREF(msg_module);
        if (!msg_class) {
            return NULL;
        }
        PyObject * msg_metaclass = PyObject_GetAttrString(msg_class,
                "__class__");
        Py_DECREF(msg_class);
        if (!msg_metaclass) {
            return NULL;
        }
        PyObject * convert_from_py_ = PyObject_GetAttrString(msg_metaclass,
                "_CONVERT_FROM_PY");
        Py_DECREF(msg_metaclass);
        if (!convert_from_py_) {
            return NULL;
        }
        convert_from_py = (convert_from_py_signature) PyCapsule_GetPointer(
                convert_from_py_, NULL);
        Py_DECREF(convert_from_py_);
        if (!convert_from_py) {
            return NULL;
        }

        insertMap(hm, hashKey, convert_from_py,hashVal);

        free(hashKey);

        return convert_from_py;
    }
}

convert_to_py_signature get_convert_to_py_signature(char* module_name,
        char* class_name,int hashVal) {

    void* data = pthread_getspecific(key);
    if (data == NULL) {
        int rc = pthread_key_create(&key, dest_tid);
        assert(rc == 0);
        HashMap* tid = createMap(10);
        rc = pthread_setspecific(key, tid);
        assert(rc == 0);
    }

    data = pthread_getspecific(key);
    assert(data != NULL);

    HashMap* hm = (HashMap*) data;

    char* prefix = "c_to_py_";
    int key_size = strlen(module_name) + strlen(class_name) + strlen(prefix)+1;

    convert_to_py_signature convert_to_py = NULL;

    if (containsKey(hm, hashVal)) {
        convert_to_py = (convert_to_py_signature) atMap(hm, hashVal);
        return convert_to_py;
    } else {
    
        char* hashKey = (char*) malloc(sizeof(char) * key_size);
        memcpy(hashKey, prefix, strlen(prefix));
        memcpy(&hashKey[strlen(prefix)], module_name, strlen(module_name));
        memcpy(&hashKey[strlen(prefix) + strlen(module_name)], class_name,
                strlen(class_name));
        hashKey[key_size-1] = '\0';
    
        printf("--------------------------------get_convert_to_py_signature containsKey:%s\n",hashKey);
        
        // get conversion function
        PyObject * msg_module = PyImport_ImportModule(module_name);
        if (!msg_module) {
            return NULL;
        }
        PyObject * msg_class = PyObject_GetAttrString(msg_module, class_name);
        Py_DECREF(msg_module);
        if (!msg_class) {
            return NULL;
        }
        PyObject * msg_metaclass = PyObject_GetAttrString(msg_class,
                "__class__");
        Py_DECREF(msg_class);
        if (!msg_metaclass) {
            return NULL;
        }
        PyObject * convert_to_py_ = PyObject_GetAttrString(msg_metaclass,
                "_CONVERT_TO_PY");
        Py_DECREF(msg_metaclass);
        if (!convert_to_py_) {
            return NULL;
        }
        convert_to_py = (convert_to_py_signature) PyCapsule_GetPointer(
                convert_to_py_, NULL);
        Py_DECREF(convert_to_py_);
        if (!convert_to_py) {
            return NULL;
        }

        insertMap(hm, hashKey, convert_to_py,hashVal);

        free(hashKey);

        return convert_to_py;
    }
}

PyObject* get_class(char* module_name,
        char* class_name,int hashVal) {

    void* data = pthread_getspecific(key);
    if (data == NULL) {
        int rc = pthread_key_create(&key, dest_tid);
        assert(rc == 0);
        HashMap* tid = createMap(10);
        rc = pthread_setspecific(key, tid);
        assert(rc == 0);
    }

    data = pthread_getspecific(key);
    assert(data != NULL);

    HashMap* hm = (HashMap*) data;

    char* prefix = "class_";
    int key_size = strlen(module_name) + strlen(class_name) + strlen(prefix)+1;

   PyObject * pymessage_class = NULL;

   if (containsKey(hm, hashVal)) {
       pymessage_class = (PyObject *) atMap(hm, hashVal);
       return pymessage_class;
   } else {
   
        char* hashKey = (char*) malloc(sizeof(char) * key_size);
        memcpy(hashKey, prefix, strlen(prefix));
        memcpy(&hashKey[strlen(prefix)], module_name, strlen(module_name));
        memcpy(&hashKey[strlen(prefix) + strlen(module_name)], class_name,
                strlen(class_name));
        hashKey[key_size-1] = '\0';
    
        printf("--------------------------------get_class containsKey:%s\n",hashKey);
        
        PyObject * pymessage_module = PyImport_ImportModule(module_name);
        assert(pymessage_module);
        pymessage_class = PyObject_GetAttrString(pymessage_module, class_name);
        assert(pymessage_class);
        Py_DECREF(pymessage_module);

        insertMap(hm, hashKey, pymessage_class,hashVal);

        free(hashKey);

        return pymessage_class;
   }
}
