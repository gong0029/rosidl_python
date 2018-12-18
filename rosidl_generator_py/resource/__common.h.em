
#ifndef ROSIDL_GENERATOR_PY_MSG_INCLUDE_COMMON_H_
#define ROSIDL_GENERATOR_PY_MSG_INCLUDE_COMMON_H_

#include <Python.h>
#include <stdbool.h>

#define KeyType char*
#define ValueType void*

#define HASHING_FUNCTION 2
#define LOAD_FACTOR_THRESHOLD 0.75

typedef PyObject *(* convert_to_py_signature)(void *);
typedef bool (* convert_from_py_signature)(PyObject *, void *);

struct HashLink {
    KeyType key;
    ValueType value;
    int hashVal;
    struct HashLink *next;
};

typedef struct HashLink HashLink;

struct HashMap {
    //array of pointers to hashLinks
    HashLink** table;
    //number of buckets in the table
    int tableSize;
    //number of hashLinks in the table
    int count;
};

typedef struct HashMap HashMap;

//the first hashing function
int stringHash1(char* str);

//the second hashing function
int stringHash2(char* str);

int getHashVal(char* str);

void _initMap(struct HashMap* ht, int tableSize);

struct HashMap* createMap(int tableSize);

void freeMap(struct HashMap* ht);

/*
 * free all memory used for your hashMap, but do not free the pointer to ht.
 * you can set why this would not work by examining main().
 * the hashMap passed into your functions was never malloc'ed, so it can't be free()'ed either.
 */
void deleteMap(struct HashMap* ht);

void _setTableSize(struct HashMap* ht, int newTableSize);

/*
 * insert the following values into a hashLink, you must create this hashLink but
 * only after you confirm that this key does not already exit in the table.
 * you cannot have two hashLinks for the word "taco".
 *
 * if a hashLink already exists in the table for the key provided you should replace that hashLink
 * (really this only requires replacing the value v).
 */
void insertMap(struct HashMap* ht, KeyType k, ValueType v, int hashVal);

/*
 * this returns the value stored in a hashLink specified by the key k.
 *
 * if the user supplies the key "taco" you should find taco in the hashTable, then
 * return a pointer to the value member of the hashLink taht represents taco.
 * keep in mind we are storing an int for value, so you don't use malloc or anthing.
 *
 * if the supplied key is not in the hashtable return NULL;
 */
ValueType atMap(struct HashMap* ht, int hashVal);

/*
 * a simple yes/no if the key is in the hashtable.
 * 0 is no, all other values are yes.
 */
int containsKey(struct HashMap* ht, int hashVal);
/*
 find the hashlink for the supplied key and remove it, also freeing the memory
 for that hashlink. it is not an error to be unable to find the hashlink, if it
 cannot be found do nothing (or print a message) but do not use an assert which
 will end your program.
 */
void removeKey(struct HashMap * ht, int hashVal);

/*
 * returns the number of hashLinks in the table
 */
int size(struct HashMap* ht);

/*
 * return the member of buckets in the table
 */
int capacity(struct HashMap *ht);

/*
 * returns the ratio of: (number of hashlinks) / (number of buckets)
 *
 * this value can range anywhere from zero (an empty table) to more then 1, which would mean that
 * there are more hashlinks then buckets (but remember hashlinks are like linked list nodes
 * so they can hang from each other)
 */
float tableLoad(struct HashMap* ht);

void printMap(struct HashMap* ht);

void printValue(ValueType v);

//===============================================================================

void dest_tid(void* v_tid);
convert_from_py_signature get_convert_from_py_signature(char* module_name,
        char* class_name,int hashVal);
        
convert_to_py_signature get_convert_to_py_signature(char* module_name,
        char* class_name,int hashVal);
PyObject* get_class(char* module_name,
        char* class_name,int hashVal);

#endif /* ROSIDL_GENERATOR_PY_MSG_INCLUDE_COMMON_H_ */

